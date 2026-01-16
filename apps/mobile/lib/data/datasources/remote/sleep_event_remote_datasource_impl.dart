import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:temp_flutter/core/types/result.dart';
import 'package:temp_flutter/core/errors/failures.dart';
import 'package:temp_flutter/data/models/sleep_event_model.dart';
import 'package:temp_flutter/data/datasources/remote/sleep_event_remote_datasource.dart';
import 'package:temp_flutter/data/datasources/remote/supabase_client_impl.dart';

/// Error types for sync operations
enum SyncErrorType {
  /// Transient error - retry later (network, timeout)
  transient,
  /// Permission error - RLS blocking (do not retry)
  permission,
  /// Validation error - constraint violation (do not retry)
  validation,
  /// Duplicate error - event already exists (treat as success)
  duplicate,
  /// Unknown error
  unknown,
}

/// Supabase implementation of SleepEventRemoteDataSource
class SleepEventRemoteDataSourceImpl implements SleepEventRemoteDataSource {
  final SupabaseClientImpl _supabaseClient;

  SleepEventRemoteDataSourceImpl({SupabaseClientImpl? supabaseClient})
      : _supabaseClient = supabaseClient ?? SupabaseClientImpl.instance;

  sb.SupabaseClient get _client => _supabaseClient.client;

  @override
  Future<Result<List<SleepEventModel>, Failure>> getSleepEventsTimeline({
    required String babyId,
    bool includeCorrected = false,
    int? limit,
    int? offset,
  }) async {
    try {
      _ensureAuthenticated();

      // Build query with filters
      var filterBuilder = _client
          .from('sleep_events')
          .select()
          .eq('baby_id', babyId);

      if (!includeCorrected) {
        filterBuilder = filterBuilder.eq('is_corrected', false);
      }

      // Apply ordering and pagination
      var query = filterBuilder
          .order('timestamp', ascending: false)
          .order('created_at', ascending: false);

      if (limit != null) {
        query = query.limit(limit);
      }

      final response = offset != null 
          ? await query.range(offset, offset + (limit ?? 100) - 1)
          : await query;
          
      final events = (response as List)
          .map((json) => SleepEventModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return Success(events);
    } catch (e) {
      return Error(_mapError(e));
    }
  }

  @override
  Future<Result<List<SleepEventModel>, Failure>> getUnsyncedEvents(String babyId) async {
    // Remote doesn't have unsynced events - they're local only
    // This method is for local datasource
    return const Success([]);
  }

  @override
  Future<Result<List<SleepEventModel>, Failure>> getNewRemoteEvents({
    required String babyId,
    required DateTime lastSyncedAt,
    int? limit,
  }) async {
    try {
      _ensureAuthenticated();

      // LEGACY: Use created_at for pull
      // @deprecated Use getNewRemoteEventsByCursor for reliable incremental sync
      var filterBuilder = _client
          .from('sleep_events')
          .select()
          .eq('baby_id', babyId)
          .gt('created_at', lastSyncedAt.toIso8601String());

      var query = filterBuilder
          .order('created_at', ascending: true);

      if (limit != null) {
        query = query.limit(limit);
      }

      final response = await query;
      final events = (response as List)
          .map((json) => SleepEventModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return Success(events);
    } catch (e) {
      return Error(_mapError(e));
    }
  }

  @override
  Future<Result<List<SleepEventModel>, Failure>> getNewRemoteEventsByCursor({
    required String babyId,
    DateTime? cursorSyncedAt,
    String? cursorId,
    int limit = 200,
  }) async {
    try {
      _ensureAuthenticated();

      // Use composite cursor (synced_at, id) for reliable incremental pull
      // synced_at is server-generated, eliminating clock-skew issues
      // 
      // Filter: (synced_at > cursorSyncedAt) OR (synced_at = cursorSyncedAt AND id > cursorId)
      // Order: synced_at ASC, id ASC
      
      final query = _client
          .from('sleep_events')
          .select()
          .eq('baby_id', babyId);

      List<Map<String, dynamic>> response;
      
      if (cursorSyncedAt == null) {
        // First pull: get all events ordered by synced_at, id
        response = await query
            .order('synced_at', ascending: true)
            .order('id', ascending: true)
            .limit(limit);
      } else {
        // Incremental pull with composite cursor
        // PostgREST doesn't support OR directly, so we use .or() filter
        final cursorSyncedAtStr = cursorSyncedAt.toUtc().toIso8601String();
        
        if (cursorId != null) {
          // Full composite cursor: (synced_at > cursor) OR (synced_at = cursor AND id > cursorId)
          response = await query
              .or('synced_at.gt.$cursorSyncedAtStr,and(synced_at.eq.$cursorSyncedAtStr,id.gt.$cursorId)')
              .order('synced_at', ascending: true)
              .order('id', ascending: true)
              .limit(limit);
        } else {
          // Only synced_at cursor (legacy migration path)
          response = await query
              .gt('synced_at', cursorSyncedAtStr)
              .order('synced_at', ascending: true)
              .order('id', ascending: true)
              .limit(limit);
        }
      }

      final events = response
          .map((json) => SleepEventModel.fromJson(json))
          .toList();

      return Success(events);
    } catch (e) {
      return Error(_mapError(e));
    }
  }

  @override
  Future<Result<SleepEventModel, Failure>> createSleepEvent(SleepEventModel event) async {
    try {
      _ensureAuthenticated();

      // Prepare event data for Supabase
      final eventData = _prepareEventForInsert(event);

      final response = await _client
          .from('sleep_events')
          .insert(eventData)
          .select()
          .single();

      return Success(SleepEventModel.fromJson(response));
    } catch (e) {
      // Check for duplicate key error (idempotency)
      final errorType = _classifyError(e);
      
      if (errorType == SyncErrorType.duplicate) {
        // Event already exists - this is success for idempotency
        // Try to fetch the existing event
        final existingResult = await getEventById(event.id);
        if (existingResult.isSuccess && existingResult.dataOrNull != null) {
          return Success(existingResult.dataOrNull!);
        }
        // If we can't fetch it, return the original event as success
        return Success(event);
      }

      return Error(_mapError(e));
    }
  }

  @override
  Future<Result<SleepEventModel, Failure>> updateSleepEvent(SleepEventModel event) async {
    try {
      _ensureAuthenticated();

      // Only update mutable fields
      // Note: synced_at is NOT set here - server trigger sets it to NOW() on UPDATE
      // This ensures synced_at is always server-generated for reliable incremental sync
      final updateData = <String, dynamic>{
        'is_corrected': event.isCorrected,
        'corrected_by': event.correctedBy,
      };

      // Include metadata if present
      if (event.metadata != null) {
        updateData['metadata'] = event.metadata;
      }

      final response = await _client
          .from('sleep_events')
          .update(updateData)
          .eq('id', event.id)
          .select()
          .single();

      return Success(SleepEventModel.fromJson(response));
    } catch (e) {
      return Error(_mapError(e));
    }
  }

  @override
  Future<Result<SleepEventModel?, Failure>> getEventById(String eventId) async {
    try {
      _ensureAuthenticated();

      final response = await _client
          .from('sleep_events')
          .select()
          .eq('id', eventId)
          .maybeSingle();

      if (response == null) {
        return const Success(null);
      }

      return Success(SleepEventModel.fromJson(response));
    } catch (e) {
      return Error(_mapError(e));
    }
  }

  /// Prepares event model for insert
  /// Note: synced_at is NOT set here - server trigger sets it to NOW() on INSERT
  /// This ensures synced_at is always server-generated for reliable incremental sync
  Map<String, dynamic> _prepareEventForInsert(SleepEventModel event) {
    final json = event.toJson();
    // Remove synced_at if present - server trigger will set it
    json.remove('synced_at');
    return json;
  }

  /// Ensures user is authenticated before remote operations
  void _ensureAuthenticated() {
    if (!_supabaseClient.isAuthenticated) {
      throw AuthFailure('User must be authenticated for remote operations');
    }
  }

  /// Classifies error type for handling
  SyncErrorType _classifyError(Object error) {
    if (error is sb.PostgrestException) {
      final code = error.code;
      final message = error.message.toLowerCase();

      // Duplicate key violation (unique constraint)
      if (code == '23505' || message.contains('duplicate') || message.contains('unique')) {
        return SyncErrorType.duplicate;
      }

      // Foreign key violation
      if (code == '23503') {
        return SyncErrorType.validation;
      }

      // RLS policy violation (insufficient privilege)
      if (code == '42501' || message.contains('permission') || message.contains('policy')) {
        return SyncErrorType.permission;
      }

      // Check constraint violation
      if (code == '23514') {
        return SyncErrorType.validation;
      }
    }

    if (error is sb.AuthException) {
      return SyncErrorType.permission;
    }

    // Network-related errors
    final errorString = error.toString().toLowerCase();
    if (errorString.contains('socket') ||
        errorString.contains('connection') ||
        errorString.contains('timeout') ||
        errorString.contains('network')) {
      return SyncErrorType.transient;
    }

    return SyncErrorType.unknown;
  }

  /// Maps Supabase errors to Failure types
  Failure _mapError(Object error) {
    final errorType = _classifyError(error);
    final message = _extractErrorMessage(error);

    switch (errorType) {
      case SyncErrorType.transient:
        return NetworkFailure(message, originalError: error);
      case SyncErrorType.permission:
        return PermissionFailure(message, originalError: error);
      case SyncErrorType.validation:
        return ValidationFailure(message, originalError: error);
      case SyncErrorType.duplicate:
        // Should not reach here - handled above
        return ValidationFailure('Duplicate event: $message', originalError: error);
      case SyncErrorType.unknown:
        return SyncFailure(message, originalError: error);
    }
  }

  /// Extracts human-readable message from error
  String _extractErrorMessage(Object error) {
    if (error is sb.PostgrestException) {
      return error.message;
    }
    if (error is sb.AuthException) {
      return error.message;
    }
    return error.toString();
  }
}


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

      // Use created_at for pull (not synced_at)
      // Backend uses created_at as source of truth for ordering
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
      final updateData = {
        'is_corrected': event.isCorrected,
        'corrected_by': event.correctedBy,
        'synced_at': DateTime.now().toUtc().toIso8601String(),
      };

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
  /// Ensures synced_at is set to now
  Map<String, dynamic> _prepareEventForInsert(SleepEventModel event) {
    final json = event.toJson();
    // Set synced_at to now (server time will be used by Supabase)
    json['synced_at'] = DateTime.now().toUtc().toIso8601String();
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


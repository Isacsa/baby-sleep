import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:temp_flutter/core/types/result.dart';
import 'package:temp_flutter/core/errors/failures.dart';
import 'package:temp_flutter/data/models/caregiver_model.dart';
import 'package:temp_flutter/data/datasources/remote/caregiver_remote_datasource.dart';
import 'package:temp_flutter/data/datasources/remote/supabase_client_impl.dart';

/// Supabase implementation of CaregiverRemoteDataSource
/// 
/// LAYERED SYNC: Caregivers are pushed AFTER babies, BEFORE events.
/// This ensures FK integrity - Baby must exist before Caregiver can reference it.
class CaregiverRemoteDataSourceImpl implements CaregiverRemoteDataSource {
  final SupabaseClientImpl _supabaseClient;

  CaregiverRemoteDataSourceImpl({SupabaseClientImpl? supabaseClient})
      : _supabaseClient = supabaseClient ?? SupabaseClientImpl.instance;

  sb.SupabaseClient get _client => _supabaseClient.client;

  @override
  Future<Result<List<CaregiverModel>, Failure>> getCaregiversForBaby(String babyId) async {
    try {
      _ensureAuthenticated();

      final response = await _client
          .from('caregivers')
          .select()
          .eq('baby_id', babyId)
          .isFilter('deleted_at', null);

      final caregivers = (response as List)
          .map((json) => CaregiverModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return Success(caregivers);
    } on sb.AuthException catch (e) {
      return Error(AuthFailure(e.message));
    } on sb.PostgrestException catch (e) {
      return Error(_mapPostgrestError(e));
    } catch (e) {
      return Error(NetworkFailure('Network error: $e'));
    }
  }

  @override
  Future<Result<CaregiverModel?, Failure>> getCaregiverById(String caregiverId) async {
    try {
      _ensureAuthenticated();

      final response = await _client
          .from('caregivers')
          .select()
          .eq('id', caregiverId)
          .isFilter('deleted_at', null)
          .maybeSingle();

      if (response == null) {
        return const Success(null);
      }

      return Success(CaregiverModel.fromJson(response));
    } on sb.AuthException catch (e) {
      return Error(AuthFailure(e.message));
    } on sb.PostgrestException catch (e) {
      return Error(_mapPostgrestError(e));
    } catch (e) {
      return Error(NetworkFailure('Network error: $e'));
    }
  }

  /// Ensures user is authenticated
  void _ensureAuthenticated() {
    if (_client.auth.currentUser == null) {
      throw const sb.AuthException('Not authenticated');
    }
  }

  // ========== SYNC PUSH METHODS (Layered Sync) ==========

  @override
  Future<Result<void, Failure>> upsertCaregiver(CaregiverModel caregiver) async {
    try {
      _ensureAuthenticated();

      // Use upsert to be idempotent - if caregiver already exists, update it
      // This is safe to retry on network failures
      // 
      // IMPORTANT: Baby MUST exist remotely before calling this.
      // The LayeredSyncOrchestrator ensures this by syncing babies first.
      await _client.from('caregivers').upsert(
        caregiver.toRemoteJson(),
        onConflict: 'id', // Primary key conflict resolution
      );

      return const Success(null);
    } on sb.AuthException catch (e) {
      return Error(AuthFailure(e.message));
    } on sb.PostgrestException catch (e) {
      return Error(_mapPostgrestError(e));
    } catch (e) {
      return Error(NetworkFailure('Network error: $e'));
    }
  }

  /// Maps Postgrest error to domain failure
  Failure _mapPostgrestError(sb.PostgrestException e) {
    final code = e.code;
    
    // RLS violation or permission errors
    if (code == '42501' || code == 'PGRST301') {
      return PermissionFailure('Permission denied: ${e.message}');
    }
    
    // Not found - return null success instead
    if (code == 'PGRST116') {
      return ValidationFailure('Caregiver not found');
    }

    // Foreign key violation - baby doesn't exist
    // This should NOT happen if LayeredSyncOrchestrator is used correctly
    if (code == '23503') {
      return ValidationFailure('Baby does not exist remotely - sync babies first: ${e.message}');
    }
    
    // Unique constraint violation (duplicate)
    if (code == '23505') {
      return ValidationFailure('Caregiver already exists: ${e.message}');
    }
    
    return NetworkFailure('Database error: ${e.message}');
  }
}


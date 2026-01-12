import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:temp_flutter/core/types/result.dart';
import 'package:temp_flutter/core/errors/failures.dart';
import 'package:temp_flutter/data/models/baby_model.dart';
import 'package:temp_flutter/data/datasources/remote/baby_remote_datasource.dart';
import 'package:temp_flutter/data/datasources/remote/supabase_client_impl.dart';

/// Supabase implementation of BabyRemoteDataSource
/// 
/// LAYERED SYNC: Babies are pushed FIRST, before caregivers and events.
/// This ensures FK integrity - Baby must exist before Caregiver can reference it.
class BabyRemoteDataSourceImpl implements BabyRemoteDataSource {
  final SupabaseClientImpl _supabaseClient;

  BabyRemoteDataSourceImpl({SupabaseClientImpl? supabaseClient})
      : _supabaseClient = supabaseClient ?? SupabaseClientImpl.instance;

  sb.SupabaseClient get _client => _supabaseClient.client;

  @override
  Future<Result<List<BabyModel>, Failure>> getAccessibleBabies() async {
    try {
      _ensureAuthenticated();

      // Get babies via caregivers view (RLS handles access)
      final response = await _client
          .from('babies')
          .select()
          .order('name');

      final babies = (response as List)
          .map((json) => BabyModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return Success(babies);
    } on sb.AuthException catch (e) {
      return Error(AuthFailure(e.message));
    } on sb.PostgrestException catch (e) {
      return Error(_mapPostgrestError(e));
    } catch (e) {
      return Error(NetworkFailure('Network error: $e'));
    }
  }

  @override
  Future<Result<BabyModel?, Failure>> getBabyById(String babyId) async {
    try {
      _ensureAuthenticated();

      final response = await _client
          .from('babies')
          .select()
          .eq('id', babyId)
          .maybeSingle();

      if (response == null) {
        return const Success(null);
      }

      return Success(BabyModel.fromJson(response));
    } on sb.AuthException catch (e) {
      return Error(AuthFailure(e.message));
    } on sb.PostgrestException catch (e) {
      return Error(_mapPostgrestError(e));
    } catch (e) {
      return Error(NetworkFailure('Network error: $e'));
    }
  }

  @override
  Future<Result<BabyModel, Failure>> createBaby({
    required String name,
    DateTime? birthDate,
  }) async {
    try {
      _ensureAuthenticated();

      final response = await _client.from('babies').insert({
        'name': name,
        'birth_date': birthDate?.toIso8601String(),
      }).select().single();

      return Success(BabyModel.fromJson(response));
    } on sb.AuthException catch (e) {
      return Error(AuthFailure(e.message));
    } on sb.PostgrestException catch (e) {
      return Error(_mapPostgrestError(e));
    } catch (e) {
      return Error(NetworkFailure('Network error: $e'));
    }
  }

  @override
  Future<Result<BabyModel, Failure>> updateBaby(BabyModel baby) async {
    try {
      _ensureAuthenticated();

      final response = await _client
          .from('babies')
          .update(baby.toRemoteJson())
          .eq('id', baby.id)
          .select()
          .single();

      return Success(BabyModel.fromJson(response));
    } on sb.AuthException catch (e) {
      return Error(AuthFailure(e.message));
    } on sb.PostgrestException catch (e) {
      return Error(_mapPostgrestError(e));
    } catch (e) {
      return Error(NetworkFailure('Network error: $e'));
    }
  }

  // ========== SYNC PUSH METHODS (Layered Sync) ==========

  @override
  Future<Result<void, Failure>> upsertBaby(BabyModel baby) async {
    try {
      _ensureAuthenticated();

      // DEBUG: Log comparison between created_by and auth.uid()
      final currentUserId = _client.auth.currentUser?.id;
      // ignore: avoid_print
      print('[BabyRemote] auth.uid() = $currentUserId');
      // ignore: avoid_print
      print('[BabyRemote] baby.createdBy = ${baby.createdBy}');
      // ignore: avoid_print
      print('[BabyRemote] Match: ${currentUserId == baby.createdBy}');
      // ignore: avoid_print
      print('[BabyRemote] Payload: ${baby.toRemoteJson()}');

      // Use INSERT instead of UPSERT
      // 
      // WHY: The RLS INSERT policy requires created_by = auth.uid()
      // UPSERT may trigger UPDATE path which has different RLS requirements
      // Since we only push babies that are not yet synced (synced_at IS NULL),
      // the baby should not exist in Supabase yet, so INSERT is correct.
      // 
      // Idempotency: If INSERT fails with duplicate key (baby already exists),
      // we catch the error and treat it as success (baby is already there).
      await _client.from('babies').insert(baby.toRemoteJson());

      return const Success(null);
    } on sb.AuthException catch (e) {
      return Error(AuthFailure(e.message));
    } on sb.PostgrestException catch (e) {
      // ignore: avoid_print
      print('[BabyRemote] PostgrestException: code=${e.code}, message=${e.message}');
      
      // Handle duplicate key as success (baby already exists)
      if (e.code == '23505') {
        // ignore: avoid_print
        print('[BabyRemote] Baby already exists in Supabase - treating as success');
        return const Success(null);
      }
      
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

  /// Maps Postgrest error to domain failure
  Failure _mapPostgrestError(sb.PostgrestException e) {
    final code = e.code;
    
    // RLS violation or permission errors
    if (code == '42501' || code == 'PGRST301') {
      return PermissionFailure('Permission denied: ${e.message}');
    }
    
    // Not found
    if (code == 'PGRST116') {
      return ValidationFailure('Baby not found');
    }
    
    // Unique constraint violation (duplicate)
    if (code == '23505') {
      return ValidationFailure('Baby already exists: ${e.message}');
    }
    
    return NetworkFailure('Database error: ${e.message}');
  }
}


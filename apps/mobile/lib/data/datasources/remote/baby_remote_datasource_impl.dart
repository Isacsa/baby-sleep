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

      // ignore: avoid_print
      print('[BabyRemote] Upserting baby: ${baby.id}');
      // ignore: avoid_print
      print('[BabyRemote] Payload: ${baby.toRemoteJson()}');

      // Strategy: INSERT first, UPDATE on duplicate key
      // 
      // WHY: The RLS INSERT policy requires created_by = auth.uid()
      // For new babies, we use INSERT.
      // For existing babies (e.g., updated birth_date), we fallback to UPDATE.
      // UPDATE is allowed by RLS if user is owner or editor (can_write).
      try {
        await _client.from('babies').insert(baby.toRemoteJson());
        // ignore: avoid_print
        print('[BabyRemote] INSERT succeeded for baby ${baby.id}');
        return const Success(null);
      } on sb.PostgrestException catch (insertError) {
        // If duplicate key (baby already exists), try UPDATE instead
        if (insertError.code == '23505') {
          // ignore: avoid_print
          print('[BabyRemote] Baby ${baby.id} exists, trying UPDATE...');
          
          // UPDATE only mutable fields (name, birth_date, updated_at)
          // created_by and created_at are immutable (enforced by DB trigger)
          await _client
              .from('babies')
              .update({
                'name': baby.name,
                'birth_date': baby.birthDate,
                'updated_at': baby.updatedAt,
              })
              .eq('id', baby.id);
          
          // ignore: avoid_print
          print('[BabyRemote] UPDATE succeeded for baby ${baby.id}');
          return const Success(null);
        }
        // Re-throw other PostgrestExceptions to be handled below
        rethrow;
      }
    } on sb.AuthException catch (e) {
      return Error(AuthFailure(e.message));
    } on sb.PostgrestException catch (e) {
      // ignore: avoid_print
      print('[BabyRemote] PostgrestException: code=${e.code}, message=${e.message}');
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


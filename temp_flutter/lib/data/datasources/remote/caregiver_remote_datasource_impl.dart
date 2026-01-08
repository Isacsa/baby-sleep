import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:temp_flutter/core/types/result.dart';
import 'package:temp_flutter/core/errors/failures.dart';
import 'package:temp_flutter/data/models/caregiver_model.dart';
import 'package:temp_flutter/data/datasources/remote/caregiver_remote_datasource.dart';
import 'package:temp_flutter/data/datasources/remote/supabase_client_impl.dart';

/// Supabase implementation of CaregiverRemoteDataSource
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
    
    return NetworkFailure('Database error: ${e.message}');
  }
}


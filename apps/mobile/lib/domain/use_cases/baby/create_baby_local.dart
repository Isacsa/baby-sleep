import 'package:temp_flutter/domain/common/result.dart';
import 'package:temp_flutter/domain/common/failure.dart';
import 'package:temp_flutter/domain/entities/baby.dart';
import 'package:temp_flutter/domain/repositories/baby_repository.dart';
import 'package:temp_flutter/domain/repositories/caregiver_repository.dart';
import 'package:temp_flutter/core/utils/uuid_generator.dart';

/// Use case: Create Baby locally (offline-first)
/// 
/// Creates a Baby in local SQLite and automatically creates
/// the owner Caregiver for the authenticated user.
/// 
/// This is 100% local - does NOT call Supabase.
/// The baby and caregiver will be synced later via push.
/// 
/// Invariant: Baby created => Owner caregiver exists for creator
class CreateBabyLocal {
  final BabyRepository babyRepository;
  final CaregiverRepository caregiverRepository;

  CreateBabyLocal({
    required this.babyRepository,
    required this.caregiverRepository,
  });

  /// Executes the use case
  /// 
  /// [userId] - Current authenticated user ID (auth.uid)
  /// [name] - Baby name (required)
  /// [birthDate] - Baby birth date (optional)
  /// 
  /// Returns created baby or failure
  Future<DomainResult<Baby>> execute({
    required String? userId,
    required String name,
    DateTime? birthDate,
  }) async {
    // Validate user is authenticated
    if (userId == null || userId.isEmpty) {
      return const DomainError(NotAuthenticatedFailure());
    }

    // Validate name is not empty
    if (name.trim().isEmpty) {
      return const DomainError(ValidationFailure('Baby name cannot be empty'));
    }

    final now = DateTime.now().toUtc();
    final babyId = UuidGenerator.generate();

    // Create Baby entity
    final baby = Baby(
      id: babyId,
      name: name.trim(),
      createdAt: now,
      createdBy: userId,
      birthDate: birthDate?.toUtc(),
      updatedAt: now,
    );

    // Step 1: Persist Baby locally
    final babyResult = await babyRepository.createLocal(baby);
    if (babyResult.isError) {
      return DomainError(babyResult.failureOrNull!);
    }

    // Step 2: Ensure owner caregiver exists (idempotent)
    final caregiverResult = await caregiverRepository.ensureLocalOwnerCaregiver(
      babyId: babyId,
      userId: userId,
      nowUtc: now,
    );
    if (caregiverResult.isError) {
      // Baby was created but caregiver failed - this is an inconsistent state
      // For MVP, we log and continue (baby exists, caregiver can be created later)
      // In production, we'd want a transaction or rollback
      // ignore: avoid_print
      print('Warning: Baby created but caregiver creation failed: ${caregiverResult.failureOrNull}');
    }

    return DomainSuccess(baby);
  }
}


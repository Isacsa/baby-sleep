import 'package:temp_flutter/domain/common/result.dart';
import 'package:temp_flutter/domain/common/failure.dart';
import 'package:temp_flutter/domain/entities/sleep_event.dart';
import 'package:temp_flutter/domain/repositories/sleep_event_repository.dart';
import 'package:temp_flutter/domain/repositories/caregiver_repository.dart';

/// Use case: Create SleepStart event
/// 
/// Creates a SleepStart event locally
/// ID must be generated externally (by caller) before calling this
/// Event is persisted with syncedAt = NULL
/// Sync engine will send to backend later
class CreateSleepStart {
  final SleepEventRepository sleepEventRepository;
  final CaregiverRepository caregiverRepository;

  CreateSleepStart({
    required this.sleepEventRepository,
    required this.caregiverRepository,
  });

  /// Executes the use case
  /// 
  /// [babyId] - Baby ID
  /// [timestamp] - When sleep started (UTC, can be in past for retroactive)
  /// [userId] - Current user ID (to get caregiver_id)
  /// [eventId] - Pre-generated UUID for the event (must be unique)
  /// [deviceId] - Device identifier string
  /// [createdAt] - When event was created locally (UTC)
  /// [persist] - Whether to persist to repository (default: true)
  ///             Set to false for validation-only in transactional flows.
  /// 
  /// Returns created event or failure
  Future<DomainResult<SleepEvent>> execute({
    required String babyId,
    required DateTime timestamp,
    required String userId,
    required String eventId,
    required String deviceId,
    required DateTime createdAt,
    bool persist = true,
  }) async {
    // Validate timestamp is UTC
    if (!timestamp.isUtc) {
      return const DomainError(ValidationFailure(
        'Timestamp must be in UTC',
      ));
    }

    // Validate timestamp is not too far in future (> 1 hour)
    final now = DateTime.now().toUtc();
    final maxFuture = now.add(const Duration(hours: 1));
    if (timestamp.isAfter(maxFuture)) {
      return const DomainError(ValidationFailure(
        'Event timestamp cannot be more than 1 hour in the future',
      ));
    }

    // Validate createdAt is UTC
    if (!createdAt.isUtc) {
      return const DomainError(ValidationFailure(
        'CreatedAt must be in UTC',
      ));
    }

    // Get user's caregiver for this baby (never use "first caregiver")
    final caregiverResult = await caregiverRepository.getCaregiverForBabyAndUser(
      babyId: babyId,
      userId: userId,
    );
    if (caregiverResult.isError) {
      return DomainError(caregiverResult.failureOrNull!);
    }

    final caregiver = caregiverResult.dataOrNull;
    if (caregiver == null) {
      return const DomainError(PermissionFailure(
        'User is not a caregiver for this baby',
      ));
    }

    // Check permissions
    if (!caregiver.canWrite) {
      return const DomainError(PermissionFailure(
        'User does not have write permissions (viewer role)',
      ));
    }

    // Create event
    final event = SleepEvent(
      id: eventId,
      babyId: babyId,
      type: SleepEventType.sleepStart,
      timestamp: timestamp,
      caregiverId: caregiver.id,
      deviceId: deviceId,
      createdAt: createdAt,
      isCorrected: false,
      syncedAt: null, // Not synced yet
      correctedBy: null,
      metadata: null,
    );

    // GUARDRAIL 2: Only persist if requested (for transactional flows)
    if (!persist) {
      return DomainSuccess(event);
    }

    // Persist locally
    return await sleepEventRepository.createSleepEvent(event);
  }
}

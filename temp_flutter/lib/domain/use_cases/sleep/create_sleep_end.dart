import 'package:temp_flutter/domain/common/result.dart';
import 'package:temp_flutter/domain/common/failure.dart';
import 'package:temp_flutter/domain/entities/sleep_event.dart';
import 'package:temp_flutter/domain/repositories/sleep_event_repository.dart';
import 'package:temp_flutter/domain/repositories/caregiver_repository.dart';

/// Use case: Create SleepEnd event
/// 
/// Creates a SleepEnd event locally
/// ID must be generated externally (by caller) before calling this
/// Event is persisted with syncedAt = NULL
/// Sync engine will send to backend later
class CreateSleepEnd {
  final SleepEventRepository sleepEventRepository;
  final CaregiverRepository caregiverRepository;

  CreateSleepEnd({
    required this.sleepEventRepository,
    required this.caregiverRepository,
  });

  /// Executes the use case
  /// 
  /// [babyId] - Baby ID
  /// [timestamp] - When sleep ended (UTC, can be in past for retroactive)
  /// [userId] - Current user ID (to get caregiver_id)
  /// [eventId] - Pre-generated UUID for the event (must be unique)
  /// [deviceId] - Device identifier string
  /// [createdAt] - When event was created locally (UTC)
  /// 
  /// Returns created event or failure
  Future<DomainResult<SleepEvent>> execute({
    required String babyId,
    required DateTime timestamp,
    required String userId,
    required String eventId,
    required String deviceId,
    required DateTime createdAt,
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

    // Get current user's caregiver for this baby
    final caregiverResult = await caregiverRepository.getCurrentUserCaregiverForBaby(babyId);
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
      type: SleepEventType.sleepEnd,
      timestamp: timestamp,
      caregiverId: caregiver.id,
      deviceId: deviceId,
      createdAt: createdAt,
      isCorrected: false,
      syncedAt: null, // Not synced yet
      correctedBy: null,
      metadata: null,
    );

    // Persist locally
    return await sleepEventRepository.createSleepEvent(event);
  }
}

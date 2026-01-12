import 'package:temp_flutter/domain/common/result.dart';
import 'package:temp_flutter/domain/common/failure.dart';
import 'package:temp_flutter/domain/entities/sleep_event.dart';
import 'package:temp_flutter/domain/repositories/sleep_event_repository.dart';
import 'package:temp_flutter/domain/repositories/caregiver_repository.dart';

/// Use case: Create correction event
/// 
/// Creates a new event that corrects an existing event
/// Corrections are always new events, never updates to originals
/// Original event must be marked as corrected separately
class CreateCorrectionEvent {
  final SleepEventRepository sleepEventRepository;
  final CaregiverRepository caregiverRepository;

  CreateCorrectionEvent({
    required this.sleepEventRepository,
    required this.caregiverRepository,
  });

  /// Executes the use case
  /// 
  /// [babyId] - Baby ID
  /// [originalEventId] - ID of event being corrected
  /// [correctedType] - Type of correction event (SleepStart or SleepEnd)
  /// [correctedTimestamp] - Corrected timestamp (UTC)
  /// [userId] - Current user ID
  /// [eventId] - Pre-generated UUID for the correction event (must be unique)
  /// [deviceId] - Device identifier string
  /// [createdAt] - When correction event was created locally (UTC)
  /// 
  /// Returns created correction event or failure
  Future<DomainResult<SleepEvent>> execute({
    required String babyId,
    required String originalEventId,
    required SleepEventType correctedType,
    required DateTime correctedTimestamp,
    required String userId,
    required String eventId,
    required String deviceId,
    required DateTime createdAt,
  }) async {
    // Validate timestamp is UTC
    if (!correctedTimestamp.isUtc) {
      return const DomainError(ValidationFailure(
        'Timestamp must be in UTC',
      ));
    }

    // Validate timestamp is not too far in future (> 1 hour)
    final now = DateTime.now().toUtc();
    final maxFuture = now.add(const Duration(hours: 1));
    if (correctedTimestamp.isAfter(maxFuture)) {
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

    // Get original event
    final originalResult = await sleepEventRepository.getEventById(originalEventId);
    if (originalResult.isError) {
      return DomainError(originalResult.failureOrNull!);
    }

    final originalEvent = originalResult.dataOrNull;
    if (originalEvent == null) {
      return const DomainError(ValidationFailure('Original event not found'));
    }

    // Validate original event belongs to same baby
    if (originalEvent.babyId != babyId) {
      return const DomainError(ValidationFailure(
        'Original event does not belong to this baby',
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

    // Create correction event
    // Note: isCorrected = true and correctedBy = originalEventId
    final correctionEvent = SleepEvent(
      id: eventId,
      babyId: babyId,
      type: correctedType,
      timestamp: correctedTimestamp,
      caregiverId: caregiver.id,
      deviceId: deviceId,
      createdAt: createdAt,
      isCorrected: true, // Correction events are marked as corrected
      syncedAt: null, // Not synced yet
      correctedBy: originalEventId, // Reference to original event
      metadata: null,
    );

    // Persist locally
    return await sleepEventRepository.createSleepEvent(correctionEvent);
  }
}

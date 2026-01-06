import '../../../core/types/result.dart';
import '../../../core/errors/failures.dart';
import '../../../core/utils/uuid_generator.dart';
import '../../../core/utils/timestamp_utils.dart';
import '../../../core/utils/device_id_manager.dart';
import '../../entities/sleep_event.dart';
import '../../repositories/sleep_event_repository.dart';
import '../../repositories/caregiver_repository.dart';

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
  /// 
  /// Returns created correction event or failure
  Future<Result<SleepEvent, Failure>> execute({
    required String babyId,
    required String originalEventId,
    required SleepEventType correctedType,
    required DateTime correctedTimestamp,
    required String userId,
  }) async {
    // Validate timestamp
    if (!TimestampUtils.isValidTimestamp(correctedTimestamp)) {
      return const Error(ValidationFailure(
        'Event timestamp cannot be more than 1 hour in the future',
      ));
    }

    // Get original event
    final originalResult = await sleepEventRepository.getEventById(originalEventId);
    if (originalResult.isError) {
      return Error(originalResult.failureOrNull!);
    }

    final originalEvent = originalResult.dataOrNull;
    if (originalEvent == null) {
      return const Error(ValidationFailure('Original event not found'));
    }

    // Validate original event belongs to same baby
    if (originalEvent.babyId != babyId) {
      return const Error(ValidationFailure(
        'Original event does not belong to this baby',
      ));
    }

    // Get current user's caregiver for this baby
    final caregiverResult = await caregiverRepository.getCurrentUserCaregiverForBaby(babyId);
    if (caregiverResult.isError) {
      return Error(caregiverResult.failureOrNull!);
    }

    final caregiver = caregiverResult.dataOrNull;
    if (caregiver == null) {
      return const Error(PermissionFailure(
        'User is not a caregiver for this baby',
      ));
    }

    // Check permissions
    if (!caregiver.canWrite) {
      return const Error(PermissionFailure(
        'User does not have write permissions (viewer role)',
      ));
    }

    // Get device ID
    final deviceId = await DeviceIdManager.getDeviceId();

    // Generate ID locally
    final eventId = UuidGenerator.generate();

    // Create correction event
    // Note: isCorrected = true and correctedBy = originalEventId
    final correctionEvent = SleepEvent(
      id: eventId,
      babyId: babyId,
      type: correctedType,
      timestamp: TimestampUtils.toUtc(correctedTimestamp),
      caregiverId: caregiver.id,
      deviceId: deviceId,
      createdAt: TimestampUtils.nowUtc(),
      isCorrected: true, // Correction events are marked as corrected
      syncedAt: null, // Not synced yet
      correctedBy: originalEventId, // Reference to original event
      metadata: null,
    );

    // Persist locally
    return await sleepEventRepository.createSleepEvent(correctionEvent);
  }
}


import '../../../core/types/result.dart';
import '../../../core/errors/failures.dart';
import '../../../core/utils/uuid_generator.dart';
import '../../../core/utils/timestamp_utils.dart';
import '../../../core/utils/device_id_manager.dart';
import '../../entities/sleep_event.dart';
import '../../repositories/sleep_event_repository.dart';
import '../../repositories/caregiver_repository.dart';

/// Use case: Create SleepStart event
/// 
/// Creates a SleepStart event locally
/// ID is generated locally before any backend communication
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
  /// 
  /// Returns created event or failure
  Future<Result<SleepEvent, Failure>> execute({
    required String babyId,
    required DateTime timestamp,
    required String userId,
  }) async {
    // Validate timestamp
    if (!TimestampUtils.isValidTimestamp(timestamp)) {
      return const Error(ValidationFailure(
        'Event timestamp cannot be more than 1 hour in the future',
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

    // Create event
    final event = SleepEvent(
      id: eventId,
      babyId: babyId,
      type: SleepEventType.sleepStart,
      timestamp: TimestampUtils.toUtc(timestamp),
      caregiverId: caregiver.id,
      deviceId: deviceId,
      createdAt: TimestampUtils.nowUtc(),
      isCorrected: false,
      syncedAt: null, // Not synced yet
      correctedBy: null,
      metadata: null,
    );

    // Persist locally
    return await sleepEventRepository.createSleepEvent(event);
  }
}


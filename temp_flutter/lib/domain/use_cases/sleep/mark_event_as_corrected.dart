import 'package:temp_flutter/domain/common/result.dart';
import 'package:temp_flutter/domain/common/failure.dart';
import 'package:temp_flutter/domain/entities/sleep_event.dart';
import 'package:temp_flutter/domain/repositories/sleep_event_repository.dart';

/// Use case: Mark event as corrected
/// 
/// Marks an existing event as corrected
/// Must be called after creating correction event
/// Only mutable fields are updated (isCorrected, correctedBy)
class MarkEventAsCorrected {
  final SleepEventRepository sleepEventRepository;

  MarkEventAsCorrected({required this.sleepEventRepository});

  /// Executes the use case
  /// 
  /// [eventId] - ID of event to mark as corrected
  /// [correctionEventId] - ID of correction event
  /// 
  /// Returns updated event or failure
  Future<DomainResult<SleepEvent>> execute({
    required String eventId,
    required String correctionEventId,
  }) async {
    // Get event to update
    final eventResult = await sleepEventRepository.getEventById(eventId);
    if (eventResult.isError) {
      return DomainError(eventResult.failureOrNull!);
    }

    final event = eventResult.dataOrNull;
    if (event == null) {
      return const DomainError(ValidationFailure('Event not found'));
    }

    // Validate correction event exists
    final correctionResult = await sleepEventRepository.getEventById(correctionEventId);
    if (correctionResult.isError) {
      return DomainError(correctionResult.failureOrNull!);
    }

    final correctionEvent = correctionResult.dataOrNull;
    if (correctionEvent == null) {
      return const DomainError(ValidationFailure('Correction event not found'));
    }

    // Validate correction event belongs to same baby
    if (correctionEvent.babyId != event.babyId) {
      return const DomainError(ValidationFailure(
        'Correction event does not belong to same baby',
      ));
    }

    // Update event
    final updatedEvent = event.copyWith(
      isCorrected: true,
      correctedBy: correctionEventId,
    );

    return await sleepEventRepository.updateSleepEvent(updatedEvent);
  }
}

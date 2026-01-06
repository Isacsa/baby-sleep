import '../../../core/types/result.dart';
import '../../../core/errors/failures.dart';
import '../../models/sleep_event_model.dart';

/// Local data source for sleep events
/// 
/// Handles local persistence of sleep events
/// Used for offline-first access
abstract class SleepEventLocalDataSource {
  /// Gets all events for a baby from local storage
  Future<Result<List<SleepEventModel>, Failure>> getEventsForBaby(String babyId);

  /// Gets events ordered by timestamp DESC, createdAt DESC
  Future<Result<List<SleepEventModel>, Failure>> getEventsTimeline({
    required String babyId,
    bool includeCorrected = false,
    int? limit,
    int? offset,
  });

  /// Gets unsynced events (syncedAt IS NULL)
  Future<Result<List<SleepEventModel>, Failure>> getUnsyncedEvents(String babyId);

  /// Gets event by ID from local storage
  Future<Result<SleepEventModel?, Failure>> getEventById(String eventId);

  /// Saves event to local storage
  Future<Result<void, Failure>> saveEvent(SleepEventModel event);

  /// Saves multiple events to local storage
  Future<Result<void, Failure>> saveEvents(List<SleepEventModel> events);

  /// Updates event in local storage
  Future<Result<void, Failure>> updateEvent(SleepEventModel event);

  /// Deletes event from local storage (should not be used, but available for edge cases)
  Future<Result<void, Failure>> deleteEvent(String eventId);
}


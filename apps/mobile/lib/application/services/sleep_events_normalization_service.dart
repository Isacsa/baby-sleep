import 'package:temp_flutter/core/errors/failures.dart';
import 'package:temp_flutter/core/types/result.dart';
import 'package:temp_flutter/data/datasources/local/sleep_event_local_datasource.dart';
import 'package:temp_flutter/data/mappers/sleep_event_mapper.dart';
import 'package:temp_flutter/domain/services/sleep_events_normalizer.dart';

/// Application service for normalizing sleep events post-merge
/// 
/// Orchestrates the normalization flow:
/// 1. Reads all events for a baby from SQLite
/// 2. Calls the pure normalizer to generate a plan
/// 3. Applies the plan in a SQLite transaction
/// 4. Returns result for provider invalidation
/// 
/// This service is baby-scoped (one baby per call)
/// and idempotent (running twice produces the same result)
class SleepEventsNormalizationService {
  final SleepEventLocalDataSource _localDataSource;

  SleepEventsNormalizationService({
    required SleepEventLocalDataSource localDataSource,
  }) : _localDataSource = localDataSource;

  /// Normalizes sleep events for a specific baby
  /// 
  /// [babyId] - The baby to normalize events for
  /// 
  /// Returns [NormalizationResult] with:
  /// - updatedEventIds: list of event IDs that were updated (for sync queue)
  /// - logs: debug logs from the normalizer
  /// 
  /// This method is idempotent: calling it twice will produce no updates on second call
  Future<Result<NormalizationResult, Failure>> normalizeForBaby(String babyId) async {
    void dbg(String msg) {
      assert(() {
        // ignore: avoid_print
        print(msg);
        return true;
      }());
    }

    dbg('[NormalizationService] ===== NORMALIZE START =====');
    dbg('[NormalizationService] babyId: $babyId');

    // 1. Read all events for this baby (including corrected for reference)
    final eventsResult = await _localDataSource.getEventsTimeline(
      babyId: babyId,
      includeCorrected: true, // Need all events to detect conflicts properly
    );

    if (eventsResult.isError) {
      dbg('[NormalizationService] Failed to read events: ${eventsResult.failureOrNull?.message}');
      return Error(eventsResult.failureOrNull!);
    }

    final eventModels = eventsResult.dataOrNull ?? [];
    dbg('[NormalizationService] Events loaded: ${eventModels.length}');

    if (eventModels.isEmpty) {
      dbg('[NormalizationService] No events to normalize');
      dbg('[NormalizationService] ===== NORMALIZE END =====');
      return const Success(NormalizationResult(
        updatedEventIds: [],
        logs: ['No events to normalize'],
      ));
    }

    // 2. Map to domain entities
    final events = eventModels.map((m) => SleepEventMapper.toDomain(m)).toList();

    // 3. Call pure normalizer
    final plan = SleepEventsNormalizer.normalize(events);

    // Log the plan
    for (final log in plan.logs) {
      dbg(log);
    }

    if (plan.isEmpty) {
      dbg('[NormalizationService] Plan is empty - no updates needed');
      dbg('[NormalizationService] ===== NORMALIZE END =====');
      return Success(NormalizationResult(
        updatedEventIds: const [],
        logs: plan.logs,
      ));
    }

    // 4. Apply plan in transaction
    final updates = plan.updates.map((u) => NormalizationUpdate(
      eventId: u.eventId,
      correctedBy: u.setCorrectedBy,
      metadataPatch: u.metadataPatch,
    )).toList();

    dbg('[NormalizationService] Applying ${updates.length} updates...');

    final applyResult = await _localDataSource.applyNormalizationUpdates(updates);

    if (applyResult.isError) {
      dbg('[NormalizationService] Failed to apply updates: ${applyResult.failureOrNull?.message}');
      return Error(applyResult.failureOrNull!);
    }

    final updatedIds = applyResult.dataOrNull ?? [];
    dbg('[NormalizationService] Applied ${updatedIds.length} updates');
    dbg('[NormalizationService] ===== NORMALIZE END =====');

    return Success(NormalizationResult(
      updatedEventIds: updatedIds,
      logs: plan.logs,
    ));
  }
}

/// Result of normalization operation
class NormalizationResult {
  /// IDs of events that were updated (for enqueuing to sync)
  final List<String> updatedEventIds;
  
  /// Debug logs from the normalizer
  final List<String> logs;

  const NormalizationResult({
    required this.updatedEventIds,
    required this.logs,
  });

  /// Check if any updates were applied
  bool get hasUpdates => updatedEventIds.isNotEmpty;
}

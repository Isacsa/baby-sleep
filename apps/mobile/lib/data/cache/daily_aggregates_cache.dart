import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:temp_flutter/core/utils/local_time_utils.dart';
import 'package:temp_flutter/domain/stats/daily_sleep_aggregate.dart';
import 'package:temp_flutter/domain/value_objects/sleep_session.dart';

/// Cache for daily sleep aggregates.
///
/// Provides incremental recalculation when sessions are added/edited/deleted.
/// Only recalculates affected days instead of the entire range.
class DailyAggregatesCache {
  /// Cached aggregates by baby ID and date key
  final Map<String, Map<String, DailySleepAggregate>> _cache = {};
  
  /// Last known sessions checksum per baby
  final Map<String, int> _sessionsChecksum = {};

  /// Gets cached aggregates for a baby and date range.
  ///
  /// Returns null if cache is stale or not available.
  List<DailySleepAggregate>? getCached({
    required String babyId,
    required DateTime startLocal,
    required DateTime endExclusiveLocal,
    required List<SleepSession> currentSessions,
  }) {
    final babyCache = _cache[babyId];
    if (babyCache == null) return null;
    
    // Check if sessions have changed
    final currentChecksum = _computeChecksum(currentSessions);
    if (_sessionsChecksum[babyId] != currentChecksum) {
      return null; // Cache is stale
    }
    
    // Try to build result from cache
    final aggregates = <DailySleepAggregate>[];
    var currentDate = startLocal;
    
    while (currentDate.isBefore(endExclusiveLocal)) {
      final key = LocalTimeUtils.dateKey(currentDate);
      final cached = babyCache[key];
      
      if (cached == null) {
        return null; // Missing day, need to recalculate
      }
      
      aggregates.add(cached);
      currentDate = LocalTimeUtils.localDayRange(currentDate).endExclusiveLocal;
    }
    
    return aggregates;
  }

  /// Updates the cache with new aggregates.
  void updateCache({
    required String babyId,
    required List<DailySleepAggregate> aggregates,
    required List<SleepSession> sessions,
  }) {
    final babyCache = _cache.putIfAbsent(babyId, () => {});
    
    for (final agg in aggregates) {
      final key = LocalTimeUtils.dateKey(agg.dateLocal);
      babyCache[key] = agg;
    }
    
    _sessionsChecksum[babyId] = _computeChecksum(sessions);
  }

  /// Invalidates cache for specific dates.
  ///
  /// Use this when sessions are edited/deleted.
  void invalidateDates({
    required String babyId,
    required List<DateTime> dates,
  }) {
    final babyCache = _cache[babyId];
    if (babyCache == null) return;
    
    for (final date in dates) {
      final key = LocalTimeUtils.dateKey(date);
      babyCache.remove(key);
    }
  }

  /// Invalidates entire cache for a baby.
  void invalidateBaby(String babyId) {
    _cache.remove(babyId);
    _sessionsChecksum.remove(babyId);
  }

  /// Clears all cached data.
  void clearAll() {
    _cache.clear();
    _sessionsChecksum.clear();
  }

  /// Computes a checksum for a list of sessions.
  ///
  /// Simple implementation based on session count and boundary timestamps.
  int _computeChecksum(List<SleepSession> sessions) {
    if (sessions.isEmpty) return 0;
    
    // Combine session count with first and last timestamps
    var checksum = sessions.length;
    
    for (final s in sessions) {
      checksum ^= s.startEvent.timestamp.millisecondsSinceEpoch;
      if (s.endEvent != null) {
        checksum ^= s.endEvent!.timestamp.millisecondsSinceEpoch;
      }
    }
    
    return checksum;
  }
}

/// Provider for the daily aggregates cache (singleton)
final dailyAggregatesCacheProvider = Provider<DailyAggregatesCache>((ref) {
  return DailyAggregatesCache();
});

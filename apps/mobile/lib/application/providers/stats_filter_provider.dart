import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:temp_flutter/application/providers/active_baby_provider.dart';
import 'package:temp_flutter/data/datasources/local/stats_filter_local_datasource.dart';
import 'package:temp_flutter/domain/stats/stats_filter_state.dart';

/// Provider for the stats filter local datasource
final statsFilterLocalDataSourceProvider = Provider<StatsFilterLocalDataSource>((ref) {
  return StatsFilterLocalDataSource();
});

/// Provider for stats filter state, scoped to the active baby.
///
/// Automatically loads persisted filters when baby changes.
/// Persists changes to SharedPreferences.
final statsFilterProvider =
    StateNotifierProvider<StatsFilterNotifier, StatsFilterState>((ref) {
  final activeBaby = ref.watch(activeBabyProvider);
  final dataSource = ref.watch(statsFilterLocalDataSourceProvider);
  
  return StatsFilterNotifier(
    babyId: activeBaby?.id,
    dataSource: dataSource,
  );
});

/// Notifier for managing stats filter state
class StatsFilterNotifier extends StateNotifier<StatsFilterState> {
  final String? babyId;
  final StatsFilterLocalDataSource dataSource;
  bool _initialized = false;

  StatsFilterNotifier({
    required this.babyId,
    required this.dataSource,
  }) : super(const StatsFilterState()) {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    if (babyId == null) {
      state = const StatsFilterState();
      _initialized = true;
      return;
    }

    final loaded = await dataSource.load(babyId!);
    state = loaded;
    _initialized = true;
  }

  Future<void> _persist() async {
    if (babyId == null || !_initialized) return;
    await dataSource.save(babyId!, state);
  }

  /// Sets the period filter
  void setPeriod(StatsPeriod period) {
    // Reset compare if switching to day (not applicable)
    final newCompare = period == StatsPeriod.day ? false : state.compareEnabled;
    
    state = state.copyWith(
      period: period,
      compareEnabled: newCompare,
      clearCustomDates: period != StatsPeriod.custom,
    );
    _persist();
  }

  /// Sets the sleep type filter
  void setSleepType(SleepTypeFilter sleepType) {
    state = state.copyWith(sleepType: sleepType);
    _persist();
  }

  /// Toggles compare mode
  void toggleCompare() {
    if (!state.canCompare) return;
    state = state.copyWith(compareEnabled: !state.compareEnabled);
    _persist();
  }

  /// Sets compare mode explicitly
  void setCompare(bool enabled) {
    if (!state.canCompare && enabled) return;
    state = state.copyWith(compareEnabled: enabled);
    _persist();
  }

  /// Sets custom date range
  void setCustomRange(DateTime start, DateTime end) {
    state = state.copyWith(
      period: StatsPeriod.custom,
      customStart: start,
      customEnd: end,
    );
    _persist();
  }

  /// Resets to default state
  void reset() {
    state = const StatsFilterState();
    _persist();
  }
}

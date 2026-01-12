/// Sync state
/// 
/// Represents current state of synchronization
enum SyncStatus {
  idle,
  syncing,
  success,
  error,
}

/// Sync state value object
class SyncState {
  final SyncStatus status;
  final DateTime? lastSyncedAt;
  final String? errorMessage;
  final int pendingEventsCount;

  const SyncState({
    required this.status,
    this.lastSyncedAt,
    this.errorMessage,
    this.pendingEventsCount = 0,
  });

  /// Creates initial sync state
  factory SyncState.initial() {
    return const SyncState(status: SyncStatus.idle);
  }

  /// Creates syncing state
  factory SyncState.syncing({required int pendingEventsCount}) {
    return SyncState(
      status: SyncStatus.syncing,
      pendingEventsCount: pendingEventsCount,
    );
  }

  /// Creates success state
  factory SyncState.success({required DateTime lastSyncedAt}) {
    return SyncState(
      status: SyncStatus.success,
      lastSyncedAt: lastSyncedAt,
    );
  }

  /// Creates error state
  factory SyncState.error({required String errorMessage, DateTime? lastSyncedAt}) {
    return SyncState(
      status: SyncStatus.error,
      errorMessage: errorMessage,
      lastSyncedAt: lastSyncedAt,
    );
  }

  SyncState copyWith({
    SyncStatus? status,
    DateTime? lastSyncedAt,
    String? errorMessage,
    int? pendingEventsCount,
  }) {
    return SyncState(
      status: status ?? this.status,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      errorMessage: errorMessage ?? this.errorMessage,
      pendingEventsCount: pendingEventsCount ?? this.pendingEventsCount,
    );
  }

  @override
  String toString() =>
      'SyncState(status: $status, lastSyncedAt: $lastSyncedAt, pendingEvents: $pendingEventsCount)';
}


import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:temp_flutter/core/types/result.dart';
import 'package:temp_flutter/core/errors/failures.dart';
import 'package:temp_flutter/data/models/sleep_event_model.dart';
import 'package:temp_flutter/data/datasources/local/sleep_event_local_datasource.dart';
import 'package:temp_flutter/data/datasources/local/local_database.dart';

/// SQLite implementation of SleepEventLocalDataSource
class SleepEventLocalDataSourceImpl implements SleepEventLocalDataSource {
  final LocalDatabase _localDatabase;

  SleepEventLocalDataSourceImpl({LocalDatabase? localDatabase})
      : _localDatabase = localDatabase ?? LocalDatabase.instance;

  @override
  Future<Result<List<SleepEventModel>, Failure>> getEventsForBaby(String babyId) async {
    try {
      final db = await _localDatabase.database;
      final maps = await db.query(
        'sleep_events',
        where: 'baby_id = ?',
        whereArgs: [babyId],
        orderBy: 'timestamp DESC, created_at DESC',
      );

      final events = maps.map((map) => _modelFromMap(map)).toList();
      return Success(events);
    } catch (e) {
      return Error(StorageFailure('Failed to get events for baby: $e', originalError: e));
    }
  }

  @override
  Future<Result<List<SleepEventModel>, Failure>> getEventsTimeline({
    required String babyId,
    bool includeCorrected = false,
    int? limit,
    int? offset,
  }) async {
    try {
      final db = await _localDatabase.database;

      String whereClause = 'baby_id = ?';
      List<Object?> whereArgs = [babyId];

      if (!includeCorrected) {
        whereClause += ' AND is_corrected = 0';
      }

      final maps = await db.query(
        'sleep_events',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'timestamp DESC, created_at DESC',
        limit: limit,
        offset: offset,
      );

      final events = maps.map((map) => _modelFromMap(map)).toList();
      return Success(events);
    } catch (e) {
      return Error(StorageFailure('Failed to get events timeline: $e', originalError: e));
    }
  }

  @override
  Future<Result<List<SleepEventModel>, Failure>> getUnsyncedEvents(String babyId) async {
    try {
      final db = await _localDatabase.database;
      final maps = await db.query(
        'sleep_events',
        where: 'baby_id = ? AND synced_at IS NULL',
        whereArgs: [babyId],
        orderBy: 'created_at ASC',
      );

      final events = maps.map((map) => _modelFromMap(map)).toList();
      return Success(events);
    } catch (e) {
      return Error(StorageFailure('Failed to get unsynced events: $e', originalError: e));
    }
  }

  @override
  Future<Result<SleepEventModel?, Failure>> getEventById(String eventId) async {
    try {
      final db = await _localDatabase.database;
      final maps = await db.query(
        'sleep_events',
        where: 'id = ?',
        whereArgs: [eventId],
        limit: 1,
      );

      if (maps.isEmpty) {
        return const Success(null);
      }

      return Success(_modelFromMap(maps.first));
    } catch (e) {
      return Error(StorageFailure('Failed to get event by ID: $e', originalError: e));
    }
  }

  @override
  Future<Result<void, Failure>> saveEvent(SleepEventModel event) async {
    try {
      final db = await _localDatabase.database;
      await db.insert(
        'sleep_events',
        _modelToMap(event),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return const Success(null);
    } catch (e) {
      return Error(StorageFailure('Failed to save event: $e', originalError: e));
    }
  }

  @override
  Future<Result<void, Failure>> saveEvents(List<SleepEventModel> events) async {
    try {
      final db = await _localDatabase.database;
      final batch = db.batch();

      for (final event in events) {
        batch.insert(
          'sleep_events',
          _modelToMap(event),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
      return const Success(null);
    } catch (e) {
      return Error(StorageFailure('Failed to save events: $e', originalError: e));
    }
  }

  @override
  Future<Result<void, Failure>> saveEventsInTransaction(List<SleepEventModel> events) async {
    try {
      final db = await _localDatabase.database;
      
      // GUARDRAIL 2: Use real SQLite transaction - all or nothing
      await db.transaction((txn) async {
        // Use batch within transaction for efficiency
        final batch = txn.batch();
        
        for (final event in events) {
          batch.insert(
            'sleep_events',
            _modelToMap(event),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        
        await batch.commit(noResult: true);
      });
      
      return const Success(null);
    } catch (e) {
      return Error(StorageFailure('Failed to save events in transaction: $e', originalError: e));
    }
  }

  @override
  Future<Result<void, Failure>> saveAndUpdateEventsInTransaction({
    required List<SleepEventModel> inserts,
    required List<SleepEventModel> updates,
  }) async {
    try {
      final db = await _localDatabase.database;
      
      // Use real SQLite transaction - all inserts and updates or nothing
      await db.transaction((txn) async {
        final batch = txn.batch();
        
        // Insert new events (correction events + new sleep events)
        for (final event in inserts) {
          batch.insert(
            'sleep_events',
            _modelToMap(event),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        
        // Update existing events (mark as corrected)
        for (final event in updates) {
          batch.update(
            'sleep_events',
            _modelToMap(event),
            where: 'id = ?',
            whereArgs: [event.id],
          );
        }
        
        await batch.commit(noResult: true);
      });
      
      return const Success(null);
    } catch (e) {
      return Error(StorageFailure('Failed to save and update events in transaction: $e', originalError: e));
    }
  }

  @override
  Future<Result<void, Failure>> updateEvent(SleepEventModel event) async {
    try {
      final db = await _localDatabase.database;
      await db.update(
        'sleep_events',
        _modelToMap(event),
        where: 'id = ?',
        whereArgs: [event.id],
      );
      return const Success(null);
    } catch (e) {
      return Error(StorageFailure('Failed to update event: $e', originalError: e));
    }
  }

  @override
  Future<Result<void, Failure>> deleteEvent(String eventId) async {
    try {
      final db = await _localDatabase.database;
      await db.delete(
        'sleep_events',
        where: 'id = ?',
        whereArgs: [eventId],
      );
      return const Success(null);
    } catch (e) {
      return Error(StorageFailure('Failed to delete event: $e', originalError: e));
    }
  }

  /// Converts database map to SleepEventModel
  SleepEventModel _modelFromMap(Map<String, dynamic> map) {
    // Handle metadata JSON string
    Map<String, dynamic>? metadata;
    if (map['metadata'] != null) {
      try {
        metadata = jsonDecode(map['metadata'] as String) as Map<String, dynamic>;
      } catch (_) {
        metadata = null;
      }
    }

    return SleepEventModel(
      id: map['id'] as String,
      babyId: map['baby_id'] as String,
      type: map['type'] as String,
      timestamp: map['timestamp'] as String,
      caregiverId: map['caregiver_id'] as String,
      deviceId: map['device_id'] as String,
      createdAt: map['created_at'] as String,
      isCorrected: (map['is_corrected'] as int) == 1,
      syncedAt: map['synced_at'] as String?,
      correctedBy: map['corrected_by'] as String?,
      metadata: metadata,
    );
  }

  /// Converts SleepEventModel to database map
  Map<String, dynamic> _modelToMap(SleepEventModel event) {
    return {
      'id': event.id,
      'baby_id': event.babyId,
      'type': event.type,
      'timestamp': event.timestamp,
      'caregiver_id': event.caregiverId,
      'device_id': event.deviceId,
      'created_at': event.createdAt,
      'is_corrected': event.isCorrected ? 1 : 0,
      'synced_at': event.syncedAt,
      'corrected_by': event.correctedBy,
      'metadata': event.metadata != null ? jsonEncode(event.metadata) : null,
    };
  }

  @override
  Future<Result<void, Failure>> markEventSynced(String eventId, DateTime syncedAt) async {
    try {
      final db = await _localDatabase.database;
      await db.update(
        'sleep_events',
        {'synced_at': syncedAt.toUtc().toIso8601String()},
        where: 'id = ?',
        whereArgs: [eventId],
      );
      return const Success(null);
    } catch (e) {
      return Error(StorageFailure('Failed to mark event synced: $e', originalError: e));
    }
  }

  @override
  Future<Result<void, Failure>> markEventSyncError(
    String eventId,
    String errorType,
    String errorMessage,
  ) async {
    try {
      final db = await _localDatabase.database;
      
      // Get existing event to preserve/merge metadata
      final existing = await db.query(
        'sleep_events',
        where: 'id = ?',
        whereArgs: [eventId],
        limit: 1,
      );

      if (existing.isEmpty) {
        return Error(StorageFailure('Event not found: $eventId'));
      }

      // Parse existing metadata
      Map<String, dynamic> metadata = {};
      final existingMetadata = existing.first['metadata'];
      if (existingMetadata != null) {
        try {
          metadata = jsonDecode(existingMetadata as String) as Map<String, dynamic>;
        } catch (_) {
          // Ignore parse errors
        }
      }

      // Add sync error info
      metadata['sync_error'] = {
        'type': errorType,
        'message': errorMessage,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      };

      await db.update(
        'sleep_events',
        {'metadata': jsonEncode(metadata)},
        where: 'id = ?',
        whereArgs: [eventId],
      );

      return const Success(null);
    } catch (e) {
      return Error(StorageFailure('Failed to mark event sync error: $e', originalError: e));
    }
  }

  @override
  Future<Result<List<SleepEventModel>, Failure>> getAllUnsyncedEvents() async {
    try {
      final db = await _localDatabase.database;
      final maps = await db.query(
        'sleep_events',
        where: 'synced_at IS NULL',
        orderBy: 'created_at ASC',
      );

      final events = maps.map((map) => _modelFromMap(map)).toList();
      return Success(events);
    } catch (e) {
      return Error(StorageFailure('Failed to get all unsynced events: $e', originalError: e));
    }
  }

  @override
  Future<Result<void, Failure>> upsertRemoteEvents(List<SleepEventModel> events) async {
    try {
      final db = await _localDatabase.database;
      final batch = db.batch();

      for (final event in events) {
        // Check if event exists
        final existing = await db.query(
          'sleep_events',
          where: 'id = ?',
          whereArgs: [event.id],
          limit: 1,
        );

        if (existing.isEmpty) {
          // Insert new event
          batch.insert(
            'sleep_events',
            _modelToMap(event),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        } else {
          // Update only mutable fields
          // Create update map with only mutable fields
          final updateMap = {
            'is_corrected': event.isCorrected ? 1 : 0,
            'corrected_by': event.correctedBy,
            'synced_at': event.syncedAt,
            'metadata': event.metadata != null ? jsonEncode(event.metadata) : null,
          };

          batch.update(
            'sleep_events',
            updateMap,
            where: 'id = ?',
            whereArgs: [event.id],
          );
        }
      }

      await batch.commit(noResult: true);
      return const Success(null);
    } catch (e) {
      return Error(StorageFailure('Failed to upsert remote events: $e', originalError: e));
    }
  }

  @override
  Future<Result<DateTime?, Failure>> getLastSyncedAt(String babyId) async {
    try {
      final db = await _localDatabase.database;
      final maps = await db.query(
        'sync_state',
        where: 'baby_id = ?',
        whereArgs: [babyId],
        limit: 1,
      );

      if (maps.isEmpty) {
        return const Success(null);
      }

      final lastSyncedAtStr = maps.first['last_synced_at'] as String;
      return Success(DateTime.parse(lastSyncedAtStr).toUtc());
    } catch (e) {
      return Error(StorageFailure('Failed to get last synced at: $e', originalError: e));
    }
  }

  @override
  Future<Result<void, Failure>> setLastSyncedAt(String babyId, DateTime lastSyncedAt) async {
    try {
      final db = await _localDatabase.database;
      final now = DateTime.now().toUtc().toIso8601String();
      
      await db.insert(
        'sync_state',
        {
          'baby_id': babyId,
          'last_synced_at': lastSyncedAt.toUtc().toIso8601String(),
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      return const Success(null);
    } catch (e) {
      return Error(StorageFailure('Failed to set last synced at: $e', originalError: e));
    }
  }

  @override
  Future<Result<SyncCursor, Failure>> getSyncCursor(String babyId) async {
    try {
      final db = await _localDatabase.database;
      final maps = await db.query(
        'sync_state',
        where: 'baby_id = ?',
        whereArgs: [babyId],
        limit: 1,
      );

      if (maps.isEmpty) {
        return Success(SyncCursor.initial());
      }

      final lastSyncedAtStr = maps.first['last_synced_at'] as String?;
      final lastSyncedId = maps.first['last_synced_id'] as String?;

      return Success(SyncCursor(
        syncedAt: lastSyncedAtStr != null 
            ? DateTime.parse(lastSyncedAtStr).toUtc() 
            : null,
        eventId: lastSyncedId,
      ));
    } catch (e) {
      return Error(StorageFailure('Failed to get sync cursor: $e', originalError: e));
    }
  }

  @override
  Future<Result<void, Failure>> setSyncCursor(String babyId, SyncCursor cursor) async {
    try {
      final db = await _localDatabase.database;
      final now = DateTime.now().toUtc().toIso8601String();
      
      await db.insert(
        'sync_state',
        {
          'baby_id': babyId,
          'last_synced_at': cursor.syncedAt?.toUtc().toIso8601String() ?? 
              DateTime.fromMillisecondsSinceEpoch(0).toUtc().toIso8601String(),
          'last_synced_id': cursor.eventId,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      return const Success(null);
    } catch (e) {
      return Error(StorageFailure('Failed to set sync cursor: $e', originalError: e));
    }
  }

  @override
  Future<Result<List<String>, Failure>> applyNormalizationUpdates(
    List<NormalizationUpdate> updates,
  ) async {
    if (updates.isEmpty) {
      return const Success([]);
    }

    try {
      final db = await _localDatabase.database;
      final updatedIds = <String>[];

      await db.transaction((txn) async {
        for (final update in updates) {
          // Get existing metadata
          final existing = await txn.query(
            'sleep_events',
            columns: ['metadata'],
            where: 'id = ?',
            whereArgs: [update.eventId],
          );

          Map<String, dynamic> newMetadata = {...update.metadataPatch};
          
          if (existing.isNotEmpty && existing.first['metadata'] != null) {
            // Merge with existing metadata (patch overwrites on conflict)
            final existingMetadata = jsonDecode(existing.first['metadata'] as String);
            if (existingMetadata is Map<String, dynamic>) {
              newMetadata = {...existingMetadata, ...update.metadataPatch};
            }
          }

          // Update the event
          await txn.update(
            'sleep_events',
            {
              'is_corrected': 1,
              'corrected_by': update.correctedBy,
              'metadata': jsonEncode(newMetadata),
            },
            where: 'id = ?',
            whereArgs: [update.eventId],
          );

          updatedIds.add(update.eventId);
        }
      });

      return Success(updatedIds);
    } catch (e) {
      return Error(StorageFailure('Failed to apply normalization updates: $e', originalError: e));
    }
  }

  // ============================================
  // SYNC QUEUE METHODS
  // ============================================

  @override
  Future<Result<void, Failure>> enqueueForSync(String eventId, SyncAction action) async {
    try {
      final db = await _localDatabase.database;
      final now = DateTime.now().toUtc().toIso8601String();
      
      await db.insert(
        'sleep_event_sync_queue',
        {
          'event_id': eventId,
          'action': action.name,
          'enqueued_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      return const Success(null);
    } catch (e) {
      return Error(StorageFailure('Failed to enqueue for sync: $e', originalError: e));
    }
  }

  @override
  Future<Result<void, Failure>> enqueueMultipleForSync(List<String> eventIds, SyncAction action) async {
    if (eventIds.isEmpty) {
      return const Success(null);
    }

    try {
      final db = await _localDatabase.database;
      final now = DateTime.now().toUtc().toIso8601String();
      
      final batch = db.batch();
      for (final eventId in eventIds) {
        batch.insert(
          'sleep_event_sync_queue',
          {
            'event_id': eventId,
            'action': action.name,
            'enqueued_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
      
      return const Success(null);
    } catch (e) {
      return Error(StorageFailure('Failed to enqueue multiple for sync: $e', originalError: e));
    }
  }

  @override
  Future<Result<void, Failure>> dequeueAfterSync(String eventId) async {
    try {
      final db = await _localDatabase.database;
      
      await db.delete(
        'sleep_event_sync_queue',
        where: 'event_id = ?',
        whereArgs: [eventId],
      );
      
      return const Success(null);
    } catch (e) {
      return Error(StorageFailure('Failed to dequeue after sync: $e', originalError: e));
    }
  }

  @override
  Future<Result<List<SyncQueueEntry>, Failure>> getPendingSyncEntries(SyncAction action) async {
    try {
      final db = await _localDatabase.database;
      
      final maps = await db.query(
        'sleep_event_sync_queue',
        where: 'action = ?',
        whereArgs: [action.name],
        orderBy: 'enqueued_at ASC',
      );
      
      final entries = maps.map((map) => SyncQueueEntry(
        eventId: map['event_id'] as String,
        action: SyncAction.values.firstWhere((a) => a.name == map['action']),
        enqueuedAt: DateTime.parse(map['enqueued_at'] as String).toUtc(),
      )).toList();
      
      return Success(entries);
    } catch (e) {
      return Error(StorageFailure('Failed to get pending sync entries: $e', originalError: e));
    }
  }

  @override
  Future<Result<List<SyncQueueEntry>, Failure>> getAllPendingSyncEntries() async {
    try {
      final db = await _localDatabase.database;
      
      final maps = await db.query(
        'sleep_event_sync_queue',
        orderBy: 'enqueued_at ASC',
      );
      
      final entries = maps.map((map) => SyncQueueEntry(
        eventId: map['event_id'] as String,
        action: SyncAction.values.firstWhere((a) => a.name == map['action']),
        enqueuedAt: DateTime.parse(map['enqueued_at'] as String).toUtc(),
      )).toList();
      
      return Success(entries);
    } catch (e) {
      return Error(StorageFailure('Failed to get all pending sync entries: $e', originalError: e));
    }
  }
}


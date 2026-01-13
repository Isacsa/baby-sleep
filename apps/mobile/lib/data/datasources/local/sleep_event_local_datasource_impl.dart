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
}


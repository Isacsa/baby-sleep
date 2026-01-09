import 'package:sqflite/sqflite.dart';
import 'package:temp_flutter/core/types/result.dart';
import 'package:temp_flutter/core/errors/failures.dart';
import 'package:temp_flutter/data/models/caregiver_model.dart';
import 'package:temp_flutter/data/datasources/local/caregiver_local_datasource.dart';
import 'package:temp_flutter/data/datasources/local/local_database.dart';

/// SQLite implementation of CaregiverLocalDataSource
class CaregiverLocalDataSourceImpl implements CaregiverLocalDataSource {
  final LocalDatabase _localDatabase;

  CaregiverLocalDataSourceImpl({LocalDatabase? localDatabase})
      : _localDatabase = localDatabase ?? LocalDatabase.instance;

  @override
  Future<Result<List<CaregiverModel>, Failure>> getCaregiversForBaby(String babyId) async {
    try {
      final db = await _localDatabase.database;
      final maps = await db.query(
        'caregivers',
        where: 'baby_id = ?',
        whereArgs: [babyId],
        orderBy: 'created_at ASC',
      );

      final caregivers = maps.map((map) => CaregiverModel.fromJson(map)).toList();
      return Success(caregivers);
    } catch (e) {
      return Error(StorageFailure('Failed to get caregivers for baby: $e', originalError: e));
    }
  }

  @override
  Future<Result<CaregiverModel?, Failure>> getCaregiverById(String caregiverId) async {
    try {
      final db = await _localDatabase.database;
      final maps = await db.query(
        'caregivers',
        where: 'id = ?',
        whereArgs: [caregiverId],
        limit: 1,
      );

      if (maps.isEmpty) {
        return const Success(null);
      }

      return Success(CaregiverModel.fromJson(maps.first));
    } catch (e) {
      return Error(StorageFailure('Failed to get caregiver by ID: $e', originalError: e));
    }
  }

  @override
  Future<Result<CaregiverModel?, Failure>> getCaregiverByUserIdForBaby({
    required String userId,
    required String babyId,
  }) async {
    try {
      final db = await _localDatabase.database;
      final maps = await db.query(
        'caregivers',
        where: 'user_id = ? AND baby_id = ?',
        whereArgs: [userId, babyId],
        limit: 1,
      );

      if (maps.isEmpty) {
        return const Success(null);
      }

      return Success(CaregiverModel.fromJson(maps.first));
    } catch (e) {
      return Error(StorageFailure('Failed to get caregiver by user ID: $e', originalError: e));
    }
  }

  @override
  Future<Result<void, Failure>> saveCaregiver(CaregiverModel caregiver) async {
    try {
      final db = await _localDatabase.database;
      await db.insert(
        'caregivers',
        caregiver.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return const Success(null);
    } catch (e) {
      return Error(StorageFailure('Failed to save caregiver: $e', originalError: e));
    }
  }

  @override
  Future<Result<void, Failure>> saveCaregivers(List<CaregiverModel> caregivers) async {
    try {
      final db = await _localDatabase.database;
      final batch = db.batch();

      for (final caregiver in caregivers) {
        batch.insert(
          'caregivers',
          caregiver.toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
      return const Success(null);
    } catch (e) {
      return Error(StorageFailure('Failed to save caregivers: $e', originalError: e));
    }
  }

  @override
  Future<Result<void, Failure>> deleteCaregiver(String caregiverId) async {
    try {
      final db = await _localDatabase.database;
      await db.delete(
        'caregivers',
        where: 'id = ?',
        whereArgs: [caregiverId],
      );
      return const Success(null);
    } catch (e) {
      return Error(StorageFailure('Failed to delete caregiver: $e', originalError: e));
    }
  }

  // ========== SYNC METHODS (Layered Sync) ==========
  // 
  // These methods support the layered sync strategy:
  // 1. Push Babies first (must exist before caregivers)
  // 2. Push Caregivers second (must exist before events)
  // 3. Push SleepEvents last (depends on caregiver existing)
  //
  // CRITICAL: We only push caregivers when their baby is already synced.
  // This prevents the "Caregiver does not exist" error on SleepEvent push.

  @override
  Future<Result<List<CaregiverModel>, Failure>> getUnsyncedCaregivers() async {
    try {
      final db = await _localDatabase.database;
      final maps = await db.query(
        'caregivers',
        where: 'synced_at IS NULL',
        orderBy: 'created_at ASC', // Sync oldest first
      );

      final caregivers = maps.map((map) => CaregiverModel.fromJson(map)).toList();
      return Success(caregivers);
    } catch (e) {
      return Error(StorageFailure('Failed to get unsynced caregivers: $e', originalError: e));
    }
  }

  @override
  Future<Result<List<CaregiverModel>, Failure>> getUnsyncedCaregiversForSyncedBabies() async {
    try {
      final db = await _localDatabase.database;
      
      // Join with babies to ensure baby is synced before we try to push caregiver
      // This is the key to layered sync - we only push caregivers when
      // their parent baby exists remotely
      final maps = await db.rawQuery('''
        SELECT c.* FROM caregivers c
        INNER JOIN babies b ON c.baby_id = b.id
        WHERE c.synced_at IS NULL
          AND b.synced_at IS NOT NULL
        ORDER BY c.created_at ASC
      ''');

      final caregivers = maps.map((map) => CaregiverModel.fromJson(map)).toList();
      return Success(caregivers);
    } catch (e) {
      return Error(StorageFailure('Failed to get unsynced caregivers for synced babies: $e', originalError: e));
    }
  }

  @override
  Future<Result<void, Failure>> markCaregiverSynced(String caregiverId, DateTime syncedAt) async {
    try {
      final db = await _localDatabase.database;
      await db.update(
        'caregivers',
        {'synced_at': syncedAt.toIso8601String()},
        where: 'id = ?',
        whereArgs: [caregiverId],
      );
      return const Success(null);
    } catch (e) {
      return Error(StorageFailure('Failed to mark caregiver as synced: $e', originalError: e));
    }
  }

  @override
  Future<Result<bool, Failure>> isCaregiverSynced(String caregiverId) async {
    try {
      final db = await _localDatabase.database;
      final maps = await db.query(
        'caregivers',
        columns: ['synced_at'],
        where: 'id = ?',
        whereArgs: [caregiverId],
        limit: 1,
      );

      if (maps.isEmpty) {
        return const Success(false); // Caregiver doesn't exist
      }

      final syncedAt = maps.first['synced_at'];
      return Success(syncedAt != null);
    } catch (e) {
      return Error(StorageFailure('Failed to check caregiver sync status: $e', originalError: e));
    }
  }
}


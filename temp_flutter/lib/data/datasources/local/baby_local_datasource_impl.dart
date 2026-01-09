import 'package:sqflite/sqflite.dart';
import 'package:temp_flutter/core/types/result.dart';
import 'package:temp_flutter/core/errors/failures.dart';
import 'package:temp_flutter/data/models/baby_model.dart';
import 'package:temp_flutter/data/datasources/local/baby_local_datasource.dart';
import 'package:temp_flutter/data/datasources/local/local_database.dart';

/// SQLite implementation of BabyLocalDataSource
class BabyLocalDataSourceImpl implements BabyLocalDataSource {
  final LocalDatabase _localDatabase;

  BabyLocalDataSourceImpl({LocalDatabase? localDatabase})
      : _localDatabase = localDatabase ?? LocalDatabase.instance;

  @override
  Future<Result<List<BabyModel>, Failure>> getBabies() async {
    try {
      final db = await _localDatabase.database;
      final maps = await db.query('babies', orderBy: 'name ASC');

      final babies = maps.map((map) => BabyModel.fromJson(map)).toList();
      return Success(babies);
    } catch (e) {
      return Error(StorageFailure('Failed to get babies: $e', originalError: e));
    }
  }

  @override
  Future<Result<BabyModel?, Failure>> getBabyById(String babyId) async {
    try {
      final db = await _localDatabase.database;
      final maps = await db.query(
        'babies',
        where: 'id = ?',
        whereArgs: [babyId],
        limit: 1,
      );

      if (maps.isEmpty) {
        return const Success(null);
      }

      return Success(BabyModel.fromJson(maps.first));
    } catch (e) {
      return Error(StorageFailure('Failed to get baby by ID: $e', originalError: e));
    }
  }

  @override
  Future<Result<void, Failure>> saveBaby(BabyModel baby) async {
    try {
      final db = await _localDatabase.database;
      await db.insert(
        'babies',
        baby.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return const Success(null);
    } catch (e) {
      return Error(StorageFailure('Failed to save baby: $e', originalError: e));
    }
  }

  @override
  Future<Result<void, Failure>> saveBabies(List<BabyModel> babies) async {
    try {
      final db = await _localDatabase.database;
      final batch = db.batch();

      for (final baby in babies) {
        batch.insert(
          'babies',
          baby.toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
      return const Success(null);
    } catch (e) {
      return Error(StorageFailure('Failed to save babies: $e', originalError: e));
    }
  }

  @override
  Future<Result<void, Failure>> deleteBaby(String babyId) async {
    try {
      final db = await _localDatabase.database;
      await db.delete(
        'babies',
        where: 'id = ?',
        whereArgs: [babyId],
      );
      return const Success(null);
    } catch (e) {
      return Error(StorageFailure('Failed to delete baby: $e', originalError: e));
    }
  }

  // ========== SYNC METHODS (Layered Sync) ==========
  // 
  // These methods support the layered sync strategy:
  // 1. Push Babies first (must exist before caregivers)
  // 2. Push Caregivers second (must exist before events)
  // 3. Push SleepEvents last (depends on caregiver existing)

  @override
  Future<Result<List<BabyModel>, Failure>> getUnsyncedBabies() async {
    try {
      final db = await _localDatabase.database;
      final maps = await db.query(
        'babies',
        where: 'synced_at IS NULL',
        orderBy: 'created_at ASC', // Sync oldest first
      );

      final babies = maps.map((map) => BabyModel.fromJson(map)).toList();
      return Success(babies);
    } catch (e) {
      return Error(StorageFailure('Failed to get unsynced babies: $e', originalError: e));
    }
  }

  @override
  Future<Result<void, Failure>> markBabySynced(String babyId, DateTime syncedAt) async {
    try {
      final db = await _localDatabase.database;
      await db.update(
        'babies',
        {'synced_at': syncedAt.toIso8601String()},
        where: 'id = ?',
        whereArgs: [babyId],
      );
      return const Success(null);
    } catch (e) {
      return Error(StorageFailure('Failed to mark baby as synced: $e', originalError: e));
    }
  }

  @override
  Future<Result<bool, Failure>> isBabySynced(String babyId) async {
    try {
      final db = await _localDatabase.database;
      final maps = await db.query(
        'babies',
        columns: ['synced_at'],
        where: 'id = ?',
        whereArgs: [babyId],
        limit: 1,
      );

      if (maps.isEmpty) {
        return const Success(false); // Baby doesn't exist
      }

      final syncedAt = maps.first['synced_at'];
      return Success(syncedAt != null);
    } catch (e) {
      return Error(StorageFailure('Failed to check baby sync status: $e', originalError: e));
    }
  }
}


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

  /// Gets caregiver by user ID for a specific baby
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
}


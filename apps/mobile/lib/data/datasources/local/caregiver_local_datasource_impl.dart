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

  // ========== PULL METHODS (Pull Active Baby Data) ==========

  @override
  Future<Result<CaregiverUpsertResult, Failure>> upsertCaregiversFromRemote(List<CaregiverModel> caregivers) async {
    if (caregivers.isEmpty) {
      return const Success(CaregiverUpsertResult(caregiversUpserted: 0));
    }

    try {
      final db = await _localDatabase.database;
      final now = DateTime.now().toUtc().toIso8601String();
      final batch = db.batch();

      for (final caregiver in caregivers) {
        // Mark as synced since they come from remote
        final caregiverWithSyncedAt = {
          ...caregiver.toJson(),
          'synced_at': now,
        };
        batch.insert(
          'caregivers',
          caregiverWithSyncedAt,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // Commit with results to get count
      final results = await batch.commit(noResult: false);
      final upsertedCount = results.length;

      // ignore: avoid_print
      print('[CaregiverLocalDS] upsertCaregiversFromRemote: caregiversUpserted=$upsertedCount');

      return Success(CaregiverUpsertResult(caregiversUpserted: upsertedCount));
    } catch (e) {
      return Error(StorageFailure('Failed to upsert caregivers from remote: $e', originalError: e));
    }
  }

  // ========== CANONICALIZATION (Post-Baby-Push) ==========
  //
  // This method aligns local caregiver IDs with remote IDs created by 
  // the Supabase trigger, ensuring sleep_events reference the canonical ID.
  //
  // IMPORTANT: Currently, only `sleep_events` references `caregivers.id`
  // in the local SQLite schema. If new tables with FK to caregivers are 
  // added in the future, update this method to include those tables.

  @override
  Future<Result<CanonicalizationResult, Failure>> canonicalizeOwnerCaregiverId({
    required String babyId,
    required String userId,
    required String remoteCaregiverId,
    required DateTime nowUtc,
  }) async {
    try {
      final db = await _localDatabase.database;

      // Run everything in a transaction for consistency
      final result = await db.transaction<CanonicalizationResult>((txn) async {
        // Step 1: Find the local owner caregiver for this baby/user
        final localOwnerMaps = await txn.query(
          'caregivers',
          where: 'baby_id = ? AND user_id = ? AND role = ?',
          whereArgs: [babyId, userId, 'owner'],
          limit: 1,
        );

        if (localOwnerMaps.isEmpty) {
          // No local owner caregiver found - skip canonicalization
          // ignore: avoid_print
          print('[Canonicalize] SKIPPED: No local owner caregiver found for '
              'babyId=$babyId, userId=$userId');
          return const CanonicalizationResult(
            strategy: 'skipped',
            localOwnerId: null,
            warning: 'No local owner caregiver found',
          );
        }

        final localOwnerId = localOwnerMaps.first['id'] as String;

        // Step 2: Check if already canonical (local ID == remote ID)
        if (localOwnerId == remoteCaregiverId) {
          // Already canonical - just ensure synced_at is set
          await txn.update(
            'caregivers',
            {'synced_at': nowUtc.toIso8601String()},
            where: 'id = ?',
            whereArgs: [localOwnerId],
          );
          // ignore: avoid_print
          print('[Canonicalize] ALREADY_CANONICAL: babyId=$babyId, '
              'caregiverId=$localOwnerId (updated synced_at)');
          return CanonicalizationResult(
            strategy: 'already_canonical',
            localOwnerId: localOwnerId,
            caregiverUpdated: 1,
          );
        }

        // Step 3: Check if remote ID already exists locally (merge case)
        final existingRemoteMaps = await txn.query(
          'caregivers',
          where: 'id = ?',
          whereArgs: [remoteCaregiverId],
          limit: 1,
        );

        int eventsUpdated = 0;
        int caregiverUpdated = 0;
        int caregiverDeleted = 0;
        String strategy;
        String? warning;

        if (existingRemoteMaps.isNotEmpty) {
          // MERGE CASE: Remote ID already exists locally
          // Validate that it matches expected fields (anti-corruption)
          final existing = existingRemoteMaps.first;
          final existingBabyId = existing['baby_id'] as String;
          final existingUserId = existing['user_id'] as String;
          final existingRole = existing['role'] as String;

          if (existingBabyId != babyId || existingUserId != userId) {
            // COLLISION: Existing caregiver doesn't match expected fields
            // Abort canonicalization to prevent data corruption
            // ignore: avoid_print
            print('[Canonicalize] ABORTED: Unexpected local caregiver collision! '
                'remoteCaregiverId=$remoteCaregiverId exists but has '
                'babyId=$existingBabyId (expected $babyId), '
                'userId=$existingUserId (expected $userId)');
            return CanonicalizationResult(
              strategy: 'aborted',
              localOwnerId: localOwnerId,
              warning: 'Unexpected local caregiver collision: '
                  'existing caregiver has different babyId/userId',
            );
          }

          if (existingRole != 'owner') {
            // Role mismatch - log warning but proceed (less critical)
            warning = 'Existing caregiver has role=$existingRole (expected owner)';
            // ignore: avoid_print
            print('[Canonicalize] WARNING: $warning');
          }

          // Merge is safe: update events to point to remote ID, delete old local caregiver
          strategy = 'merge_existing';

          // Update sleep_events to reference the remote (existing) caregiver ID
          // NOTE: Only sleep_events references caregivers.id in current schema
          eventsUpdated = await txn.rawUpdate(
            'UPDATE sleep_events SET caregiver_id = ? WHERE baby_id = ? AND caregiver_id = ?',
            [remoteCaregiverId, babyId, localOwnerId],
          );

          // Delete the old local owner caregiver (it's now merged)
          caregiverDeleted = await txn.delete(
            'caregivers',
            where: 'id = ?',
            whereArgs: [localOwnerId],
          );

          // Ensure the existing remote caregiver has synced_at set
          await txn.update(
            'caregivers',
            {'synced_at': nowUtc.toIso8601String()},
            where: 'id = ?',
            whereArgs: [remoteCaregiverId],
          );

          // ignore: avoid_print
          print('[Canonicalize] MERGE_EXISTING: babyId=$babyId, '
              'localOwnerId=$localOwnerId -> remoteOwnerId=$remoteCaregiverId, '
              'eventsUpdated=$eventsUpdated, caregiverDeleted=$caregiverDeleted');
        } else {
          // SWAP PK CASE: Remote ID doesn't exist locally
          // Update events first, then swap the caregiver PK
          strategy = 'swap_pk';

          // Update sleep_events to reference the remote caregiver ID
          // NOTE: Only sleep_events references caregivers.id in current schema
          eventsUpdated = await txn.rawUpdate(
            'UPDATE sleep_events SET caregiver_id = ? WHERE baby_id = ? AND caregiver_id = ?',
            [remoteCaregiverId, babyId, localOwnerId],
          );

          // Swap the caregiver PK to the remote ID and set synced_at
          caregiverUpdated = await txn.rawUpdate(
            'UPDATE caregivers SET id = ?, synced_at = ? WHERE id = ?',
            [remoteCaregiverId, nowUtc.toIso8601String(), localOwnerId],
          );

          // ignore: avoid_print
          print('[Canonicalize] SWAP_PK: babyId=$babyId, '
              'localOwnerId=$localOwnerId -> remoteOwnerId=$remoteCaregiverId, '
              'eventsUpdated=$eventsUpdated, caregiverUpdated=$caregiverUpdated');
        }

        // Log warning if localOwnerId existed but no events were updated
        if (eventsUpdated == 0) {
          final noEventsWarning = 'Local owner caregiver existed but no events were updated '
              '(may be normal if no events created yet)';
          // ignore: avoid_print
          print('[Canonicalize] WARNING: $noEventsWarning');
          warning = warning != null ? '$warning; $noEventsWarning' : noEventsWarning;
        }

        return CanonicalizationResult(
          strategy: strategy,
          localOwnerId: localOwnerId,
          eventsUpdated: eventsUpdated,
          caregiverUpdated: caregiverUpdated,
          caregiverDeleted: caregiverDeleted,
          warning: warning,
        );
      });

      return Success(result);
    } catch (e) {
      // ignore: avoid_print
      print('[Canonicalize] ERROR: Failed to canonicalize caregiver for '
          'babyId=$babyId, userId=$userId, remoteCaregiverId=$remoteCaregiverId: $e');
      return Error(StorageFailure(
        'Failed to canonicalize owner caregiver ID: $e',
        originalError: e,
      ));
    }
  }
}


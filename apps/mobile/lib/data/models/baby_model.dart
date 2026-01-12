import 'package:temp_flutter/domain/entities/baby.dart';

/// Baby data model
/// 
/// Used for JSON serialization/deserialization
/// Maps between domain entity and data representation
/// 
/// syncedAt: Used for layered sync (Baby → Caregiver → SleepEvent)
/// - NULL = never synced (local only, not yet pushed to Supabase)
/// - ISO8601 = pushed to Supabase at that timestamp
class BabyModel {
  final String id;
  final String name;
  final String createdAt; // ISO 8601 string
  final String createdBy;
  final String? birthDate; // ISO 8601 string, nullable
  final String updatedAt; // ISO 8601 string
  final String? syncedAt; // ISO 8601 string, nullable (null = not synced)

  BabyModel({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.createdBy,
    this.birthDate,
    required this.updatedAt,
    this.syncedAt,
  });

  /// Whether this baby has been synced to the remote backend
  bool get isSynced => syncedAt != null;

  /// Converts to domain entity
  Baby toDomain() {
    return Baby(
      id: id,
      name: name,
      createdAt: DateTime.parse(createdAt).toUtc(),
      createdBy: createdBy,
      birthDate: birthDate != null ? DateTime.parse(birthDate!).toUtc() : null,
      updatedAt: DateTime.parse(updatedAt).toUtc(),
    );
  }

  /// Creates from domain entity
  factory BabyModel.fromDomain(Baby baby) {
    return BabyModel(
      id: baby.id,
      name: baby.name,
      createdAt: baby.createdAt.toIso8601String(),
      createdBy: baby.createdBy,
      birthDate: baby.birthDate?.toIso8601String(),
      updatedAt: baby.updatedAt.toIso8601String(),
    );
  }

  /// Creates from JSON (SQLite or Supabase response)
  factory BabyModel.fromJson(Map<String, dynamic> json) {
    return BabyModel(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: json['created_at'] as String,
      createdBy: json['created_by'] as String,
      birthDate: json['birth_date'] as String?,
      updatedAt: json['updated_at'] as String,
      syncedAt: json['synced_at'] as String?,
    );
  }

  /// Converts to JSON for SQLite (includes synced_at)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt,
      'created_by': createdBy,
      'birth_date': birthDate,
      'updated_at': updatedAt,
      'synced_at': syncedAt,
    };
  }

  /// Converts to JSON for Supabase push (excludes synced_at, it's local-only)
  Map<String, dynamic> toRemoteJson() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt,
      'created_by': createdBy,
      'birth_date': birthDate,
      'updated_at': updatedAt,
    };
  }

  /// Creates a copy with synced_at set (used after successful push)
  BabyModel copyWithSynced(DateTime syncedAt) {
    return BabyModel(
      id: id,
      name: name,
      createdAt: createdAt,
      createdBy: createdBy,
      birthDate: birthDate,
      updatedAt: updatedAt,
      syncedAt: syncedAt.toIso8601String(),
    );
  }
}


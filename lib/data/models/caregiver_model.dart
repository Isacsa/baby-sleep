import '../../domain/entities/caregiver.dart';

/// Caregiver data model
/// 
/// Used for JSON serialization/deserialization
/// Maps between domain entity and data representation
class CaregiverModel {
  final String id;
  final String babyId;
  final String userId;
  final String role; // 'owner', 'editor', 'viewer'
  final String createdAt; // ISO 8601 string
  final String updatedAt; // ISO 8601 string
  final String? invitedBy;

  CaregiverModel({
    required this.id,
    required this.babyId,
    required this.userId,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
    this.invitedBy,
  });

  /// Converts to domain entity
  Caregiver toDomain() {
    return Caregiver(
      id: id,
      babyId: babyId,
      userId: userId,
      role: _roleFromString(role),
      createdAt: DateTime.parse(createdAt).toUtc(),
      updatedAt: DateTime.parse(updatedAt).toUtc(),
      invitedBy: invitedBy,
    );
  }

  /// Creates from domain entity
  factory CaregiverModel.fromDomain(Caregiver caregiver) {
    return CaregiverModel(
      id: caregiver.id,
      babyId: caregiver.babyId,
      userId: caregiver.userId,
      role: _roleToString(caregiver.role),
      createdAt: caregiver.createdAt.toIso8601String(),
      updatedAt: caregiver.updatedAt.toIso8601String(),
      invitedBy: caregiver.invitedBy,
    );
  }

  /// Creates from JSON
  factory CaregiverModel.fromJson(Map<String, dynamic> json) {
    return CaregiverModel(
      id: json['id'] as String,
      babyId: json['baby_id'] as String,
      userId: json['user_id'] as String,
      role: json['role'] as String,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
      invitedBy: json['invited_by'] as String?,
    );
  }

  /// Converts to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'baby_id': babyId,
      'user_id': userId,
      'role': role,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'invited_by': invitedBy,
    };
  }

  static CaregiverRole _roleFromString(String role) {
    switch (role) {
      case 'owner':
        return CaregiverRole.owner;
      case 'editor':
        return CaregiverRole.editor;
      case 'viewer':
        return CaregiverRole.viewer;
      default:
        throw ArgumentError('Invalid role: $role');
    }
  }

  static String _roleToString(CaregiverRole role) {
    switch (role) {
      case CaregiverRole.owner:
        return 'owner';
      case CaregiverRole.editor:
        return 'editor';
      case CaregiverRole.viewer:
        return 'viewer';
    }
  }
}


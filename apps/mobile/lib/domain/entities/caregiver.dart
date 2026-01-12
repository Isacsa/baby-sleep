/// Caregiver role enum
enum CaregiverRole {
  owner,
  editor,
  viewer,
}

/// Caregiver entity
/// 
/// Represents the relationship between an authenticated user and a baby.
/// Defines permissions (owner, editor, viewer).
/// Used for authorship and auditing.
class Caregiver {
  final String id; // caregiver_id
  final String babyId;
  final String userId;
  final CaregiverRole role;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? invitedBy;

  const Caregiver({
    required this.id,
    required this.babyId,
    required this.userId,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
    this.invitedBy,
  });

  /// Creates a copy with updated fields
  Caregiver copyWith({
    String? id,
    String? babyId,
    String? userId,
    CaregiverRole? role,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? invitedBy,
  }) {
    return Caregiver(
      id: id ?? this.id,
      babyId: babyId ?? this.babyId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      invitedBy: invitedBy ?? this.invitedBy,
    );
  }

  /// Checks if caregiver can write (owner or editor)
  bool get canWrite => role == CaregiverRole.owner || role == CaregiverRole.editor;

  /// Checks if caregiver is owner
  bool get isOwner => role == CaregiverRole.owner;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Caregiver &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Caregiver(id: $id, babyId: $babyId, role: $role)';
}


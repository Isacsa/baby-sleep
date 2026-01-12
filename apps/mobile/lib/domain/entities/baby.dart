/// Baby entity
/// 
/// Represents a real child.
/// Central aggregator of all data (sleep, milestones, diary, tips).
/// Has multiple caregivers.
/// Does not belong to a single user.
class Baby {
  final String id;
  final String name;
  final DateTime createdAt;
  final String createdBy;
  final DateTime? birthDate;
  final DateTime updatedAt;

  const Baby({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.createdBy,
    this.birthDate,
    required this.updatedAt,
  });

  /// Creates a copy with updated fields
  Baby copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    String? createdBy,
    DateTime? birthDate,
    DateTime? updatedAt,
  }) {
    return Baby(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      birthDate: birthDate ?? this.birthDate,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Baby &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Baby(id: $id, name: $name)';
}


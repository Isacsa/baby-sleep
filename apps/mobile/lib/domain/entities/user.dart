/// User entity
/// 
/// Represents authenticated user context (auth.uid())
/// Source of truth is Supabase Auth
/// Not persisted in domain model, comes from authentication system
class User {
  final String id; // auth.uid()
  final String? email; // Optional, for display

  const User({
    required this.id,
    this.email,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'User(id: $id, email: $email)';
}


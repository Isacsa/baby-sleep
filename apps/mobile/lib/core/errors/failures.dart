/// Base class for all failures in the application
/// 
/// Failures represent expected errors that can be handled gracefully
abstract class Failure {
  final String message;
  final Object? originalError;

  const Failure(this.message, {this.originalError});

  @override
  String toString() => message;
}

/// Failure for network-related errors
class NetworkFailure extends Failure {
  const NetworkFailure(super.message, {super.originalError});
}

/// Failure for authentication/authorization errors
class AuthFailure extends Failure {
  const AuthFailure(super.message, {super.originalError});
}

/// Failure for permission errors (RLS blocking)
class PermissionFailure extends Failure {
  const PermissionFailure(super.message, {super.originalError});
}

/// Failure for validation errors
class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {super.originalError});
}

/// Failure for sync errors
class SyncFailure extends Failure {
  const SyncFailure(super.message, {super.originalError});
}

/// Failure for local storage errors
class StorageFailure extends Failure {
  const StorageFailure(super.message, {super.originalError});
}


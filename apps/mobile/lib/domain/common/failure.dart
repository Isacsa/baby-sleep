/// Base class for all failures in domain layer
/// 
/// Failures represent expected errors that can be handled gracefully
/// Domain layer is independent and doesn't depend on core layer
abstract class DomainFailure {
  final String message;

  const DomainFailure(this.message);

  @override
  String toString() => message;
}

/// Failure for validation errors
class ValidationFailure extends DomainFailure {
  const ValidationFailure(super.message);
}

/// Failure for permission errors (RLS blocking)
class PermissionFailure extends DomainFailure {
  const PermissionFailure(super.message);
}

/// Failure for network-related errors
class NetworkFailure extends DomainFailure {
  const NetworkFailure(super.message);
}

/// Failure for storage errors
class StorageFailure extends DomainFailure {
  const StorageFailure(super.message);
}

/// Failure for not authenticated errors
class NotAuthenticatedFailure extends DomainFailure {
  const NotAuthenticatedFailure([String message = 'User is not authenticated'])
      : super(message);
}


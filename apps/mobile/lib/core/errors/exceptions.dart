/// Base class for all exceptions in the application
/// 
/// Exceptions represent unexpected errors that should be caught and converted to Failures
abstract class AppException implements Exception {
  final String message;
  final Object? originalError;

  AppException(this.message, {this.originalError});

  @override
  String toString() => message;
}

/// Exception for network-related errors
class NetworkException extends AppException {
  NetworkException(super.message, {super.originalError});
}

/// Exception for authentication errors
class AuthException extends AppException {
  AuthException(super.message, {super.originalError});
}

/// Exception for permission errors
class PermissionException extends AppException {
  PermissionException(super.message, {super.originalError});
}

/// Exception for validation errors
class ValidationException extends AppException {
  ValidationException(super.message, {super.originalError});
}

/// Exception for storage errors
class StorageException extends AppException {
  StorageException(super.message, {super.originalError});
}


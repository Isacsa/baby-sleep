import 'exceptions.dart';
import 'failures.dart';

/// Maps exceptions to failures
/// 
/// Converts unexpected exceptions into expected failures that can be handled
class ErrorHandler {
  ErrorHandler._();

  /// Converts an exception to a failure
  static Failure handleException(Object error) {
    if (error is AppException) {
      return _mapExceptionToFailure(error);
    }

    // Unknown error - wrap as generic failure
    return NetworkFailure(
      'Unexpected error: ${error.toString()}',
      originalError: error,
    );
  }

  static Failure _mapExceptionToFailure(AppException exception) {
    if (exception is NetworkException) {
      return NetworkFailure(exception.message, originalError: exception.originalError);
    }
    if (exception is AuthException) {
      return AuthFailure(exception.message, originalError: exception.originalError);
    }
    if (exception is PermissionException) {
      return PermissionFailure(exception.message, originalError: exception.originalError);
    }
    if (exception is ValidationException) {
      return ValidationFailure(exception.message, originalError: exception.originalError);
    }
    if (exception is StorageException) {
      return StorageFailure(exception.message, originalError: exception.originalError);
    }

    return NetworkFailure(exception.message, originalError: exception.originalError);
  }
}


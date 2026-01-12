import 'package:temp_flutter/core/errors/failures.dart';

/// Result pattern for error handling
/// 
/// Represents either success (T) or failure (Failure)
/// Prevents null errors and makes error handling explicit
sealed class Result<T, F extends Failure> {
  const Result();
}

/// Success result containing data
final class Success<T, F extends Failure> extends Result<T, F> {
  final T data;

  const Success(this.data);
}

/// Failure result containing error
final class Error<T, F extends Failure> extends Result<T, F> {
  final F failure;

  const Error(this.failure);
}

/// Extension methods for Result
extension ResultExtensions<T, F extends Failure> on Result<T, F> {
  /// Returns true if result is success
  bool get isSuccess => this is Success<T, F>;

  /// Returns true if result is error
  bool get isError => this is Error<T, F>;

  /// Gets data if success, null otherwise
  T? get dataOrNull => switch (this) {
        Success<T, F>(:final data) => data,
        Error<T, F>() => null,
      };

  /// Gets failure if error, null otherwise
  F? get failureOrNull => switch (this) {
        Success<T, F>() => null,
        Error<T, F>(:final failure) => failure,
      };

  /// Maps success value to another type
  Result<R, F> map<R>(R Function(T) mapper) {
    return switch (this) {
      Success<T, F>(:final data) => Success(mapper(data)),
      Error<T, F>(:final failure) => Error(failure),
    };
  }

  /// Maps failure to another failure type
  Result<T, F2> mapFailure<F2 extends Failure>(F2 Function(F) mapper) {
    return switch (this) {
      Success<T, F>(:final data) => Success(data),
      Error<T, F>(:final failure) => Error(mapper(failure)),
    };
  }
}


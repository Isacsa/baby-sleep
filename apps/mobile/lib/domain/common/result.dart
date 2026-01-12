import 'failure.dart';

/// Result pattern for domain layer
/// 
/// Represents either success (T) or failure (DomainFailure)
/// Domain layer is independent and doesn't depend on core layer
sealed class DomainResult<T> {
  const DomainResult();
}

/// Success result containing data
final class DomainSuccess<T> extends DomainResult<T> {
  final T data;

  const DomainSuccess(this.data);
}

/// Failure result containing error
final class DomainError<T> extends DomainResult<T> {
  final DomainFailure failure;

  const DomainError(this.failure);
}

/// Extension methods for DomainResult
extension DomainResultExtensions<T> on DomainResult<T> {
  /// Returns true if result is success
  bool get isSuccess => this is DomainSuccess<T>;

  /// Returns true if result is error
  bool get isError => this is DomainError<T>;

  /// Gets data if success, null otherwise
  T? get dataOrNull => switch (this) {
        DomainSuccess<T>(:final data) => data,
        DomainError<T>() => null,
      };

  /// Gets failure if error, null otherwise
  DomainFailure? get failureOrNull => switch (this) {
        DomainSuccess<T>() => null,
        DomainError<T>(:final failure) => failure,
      };
}


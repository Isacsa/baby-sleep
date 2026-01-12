import 'package:temp_flutter/core/types/result.dart' as core;
import 'package:temp_flutter/core/errors/failures.dart' as core_failures;
import 'package:temp_flutter/domain/common/result.dart';
import 'package:temp_flutter/domain/common/failure.dart';

/// Adapter between core Result and domain DomainResult
/// 
/// Converts between Result<T, Failure> (core) and DomainResult<T> (domain)
/// Used in data layer to bridge between core types and domain types
class ResultAdapter {
  ResultAdapter._();

  /// Converts core Result to domain DomainResult
  static DomainResult<T> toDomain<T>(core.Result<T, core_failures.Failure> result) {
    return switch (result) {
      core.Success<T, core_failures.Failure>(:final data) => DomainSuccess(data),
      core.Error<T, core_failures.Failure>(:final failure) => DomainError(_toDomainFailure(failure)),
    };
  }

  /// Converts domain DomainResult to core Result
  static core.Result<T, core_failures.Failure> toCore<T>(DomainResult<T> result) {
    if (result.isSuccess) {
      return core.Success(result.dataOrNull!);
    } else {
      final failure = result.failureOrNull!;
      return core.Error(_toCoreFailure(failure));
    }
  }

  /// Converts core Failure to domain DomainFailure
  static DomainFailure _toDomainFailure(core_failures.Failure failure) {
    if (failure is core_failures.ValidationFailure) {
      return ValidationFailure(failure.message);
    }
    if (failure is core_failures.PermissionFailure) {
      return PermissionFailure(failure.message);
    }
    if (failure is core_failures.NetworkFailure) {
      return NetworkFailure(failure.message);
    }
    if (failure is core_failures.StorageFailure) {
      return StorageFailure(failure.message);
    }
    // Generic failure
    return NetworkFailure(failure.message);
  }

  /// Converts domain DomainFailure to core Failure
  static core_failures.Failure _toCoreFailure(DomainFailure failure) {
    if (failure is ValidationFailure) {
      return core_failures.ValidationFailure(failure.message);
    }
    if (failure is PermissionFailure) {
      return core_failures.PermissionFailure(failure.message);
    }
    if (failure is NetworkFailure) {
      return core_failures.NetworkFailure(failure.message);
    }
    if (failure is StorageFailure) {
      return core_failures.StorageFailure(failure.message);
    }
    // Generic failure
    return core_failures.NetworkFailure(failure.message);
  }

  /// Converts core Failure to domain DomainFailure (public helper)
  static DomainFailure failureToDomain(core_failures.Failure failure) {
    return _toDomainFailure(failure);
  }
}


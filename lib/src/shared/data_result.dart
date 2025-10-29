import 'package:equatable/equatable.dart';

/// Represents the result of a data-layer operation.
class DataResult<T> extends Equatable {
  const DataResult._({
    this.value,
    this.error,
  });

  /// Returns a success result carrying [value].
  const DataResult.success(T value) : this._(value: value);

  /// Returns a failure result carrying an error description.
  const DataResult.failure(this.error) : value = null;

  /// The successful payload, if any.
  final T? value;

  /// The error detail for a failure case.
  final Object? error;

  /// Whether this result represents a success state.
  bool get isSuccess => value != null;

  /// Returns the error payload when [isSuccess] is false, otherwise `null`.
  Object? get errorOrNull => isSuccess ? null : error;

  /// Returns the value when [isSuccess] is true, otherwise throws a [StateError].
  T requireValue() {
    if (!isSuccess) {
      throw StateError('Result has no value: $error');
    }
    return value as T;
  }

  /// Maps the underlying value when the result is successful.
  DataResult<R> map<R>(R Function(T value) transform) {
    if (!isSuccess) {
      return DataResult<R>._(error: error);
    }
    return DataResult<R>.success(transform(value as T));
  }

  @override
  List<Object?> get props => [value, error];
}

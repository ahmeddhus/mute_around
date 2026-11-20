import 'package:mute_around/core/failures.dart';

/// The outcome of an operation that can fail: [Ok] with a value, or [Err]
/// with a [Failure].
///
/// Repositories and use cases return a `Result` instead of throwing across
/// layers. Handle it with a `switch`:
///
/// ```dart
/// switch (await startPipeline()) {
///   case Ok(:final value): ...
///   case Err(:final failure): ...
/// }
/// ```
sealed class Result<T> {
  const Result();

  /// Whether this is an [Ok].
  bool get isOk => this is Ok<T>;

  /// The value if this is an [Ok], otherwise `null`.
  T? get valueOrNull => switch (this) {
    Ok(:final value) => value,
    Err() => null,
  };

  /// The failure if this is an [Err], otherwise `null`.
  Failure? get failureOrNull => switch (this) {
    Ok() => null,
    Err(:final failure) => failure,
  };
}

/// A successful [Result].
final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;

  @override
  bool operator ==(Object other) => other is Ok<T> && other.value == value;

  @override
  int get hashCode => Object.hash(Ok, value);

  @override
  String toString() => 'Ok($value)';
}

/// A failed [Result].
final class Err<T> extends Result<T> {
  const Err(this.failure);

  final Failure failure;

  @override
  bool operator ==(Object other) => other is Err<T> && other.failure == failure;

  @override
  int get hashCode => Object.hash(Err, failure);

  @override
  String toString() => 'Err($failure)';
}

/// The value of a [Result] that carries no data.
typedef Unit = ();

/// The single [Unit] value.
const Unit unit = ();

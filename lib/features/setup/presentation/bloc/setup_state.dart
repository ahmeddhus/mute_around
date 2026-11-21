part of 'setup_cubit.dart';

/// What the setup screen is busy doing.
enum SetupActivity { idle, installing, requestingPermission }

@freezed
abstract class SetupState with _$SetupState {
  const factory SetupState({
    /// `null` until the first check finishes.
    Readiness? readiness,
    @Default(SetupActivity.idle) SetupActivity activity,

    /// The last action's failure, shown on the setup screen.
    Failure? failure,
  }) = _SetupState;

  const SetupState._();

  bool get isChecked => readiness != null;

  bool get isReady => readiness?.isReady ?? false;
}

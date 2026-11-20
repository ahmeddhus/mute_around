import 'package:mute_around/core/failures.dart';
import 'package:mute_around/core/native/mute_engine.ffigen.dart';

/// Maps a negative `me_result` code from the native engine to a [Failure].
/// [detail] is the engine's `me_last_error` text, if any.
Failure failureFromEngineResult(int code, [String detail = '']) =>
    switch (code) {
      ME_ERR_PERMISSION_DENIED => PermissionDenied(detail),
      ME_ERR_NOT_FOUND => DeviceNotFound(detail),
      ME_ERR_DEVICE => DeviceFailure(detail),
      ME_ERR_MODEL => ModelLoadFailure(detail),
      ME_ERR_STATE => EngineStateFailure(detail),
      ME_ERR_INVALID_ARG => UnknownFailure('Invalid argument. $detail'.trim()),
      _ => UnknownFailure('Engine error $code. $detail'.trim()),
    };

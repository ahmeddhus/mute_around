import 'package:flutter_test/flutter_test.dart';
import 'package:mute_around/core/failures.dart';
import 'package:mute_around/core/native/engine_errors.dart';
import 'package:mute_around/core/native/mute_engine.ffigen.dart';

void main() {
  test('maps every me_result error code', () {
    expect(
      failureFromEngineResult(ME_ERR_PERMISSION_DENIED, 'no'),
      const PermissionDenied('no'),
    );
    expect(failureFromEngineResult(ME_ERR_NOT_FOUND), isA<DeviceNotFound>());
    expect(failureFromEngineResult(ME_ERR_DEVICE), isA<DeviceFailure>());
    expect(failureFromEngineResult(ME_ERR_MODEL), isA<ModelLoadFailure>());
    expect(failureFromEngineResult(ME_ERR_STATE), isA<EngineStateFailure>());
    expect(failureFromEngineResult(ME_ERR_INVALID_ARG), isA<UnknownFailure>());
  });

  test('unknown codes become UnknownFailure with the code', () {
    expect(
      failureFromEngineResult(-99, 'boom'),
      const UnknownFailure('Engine error -99. boom'),
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:mute_around/core/failures.dart';
import 'package:mute_around/core/result.dart';

void main() {
  group('Result', () {
    test('Ok exposes its value', () {
      const Result<int> result = Ok(3);
      expect(result.isOk, isTrue);
      expect(result.valueOrNull, 3);
      expect(result.failureOrNull, isNull);
    });

    test('Err exposes its failure', () {
      const Result<int> result = Err(DeviceNotFound('usb'));
      expect(result.isOk, isFalse);
      expect(result.valueOrNull, isNull);
      expect(result.failureOrNull, const DeviceNotFound('usb'));
    });

    test('has value equality', () {
      expect(const Ok(1), const Ok(1));
      expect(const Ok(1), isNot(const Ok(2)));
      expect(
        const Err<int>(PermissionDenied()),
        const Err<int>(PermissionDenied()),
      );
      expect(
        const Err<int>(PermissionDenied()),
        isNot(const Err<int>(DeviceFailure())),
      );
    });

    test('is exhaustive in a switch', () {
      String describe(Result<int> r) => switch (r) {
        Ok(:final value) => 'ok $value',
        Err(:final failure) => 'err $failure',
      };
      expect(describe(const Ok(1)), 'ok 1');
      expect(describe(const Err(UnknownFailure('x'))), 'err UnknownFailure(x)');
    });
  });
}

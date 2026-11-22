import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mute_around/core/failures.dart';
import 'package:mute_around/core/result.dart';
import 'package:mute_around/features/setup/domain/entities/mic_permission.dart';
import 'package:mute_around/features/setup/domain/entities/readiness.dart';
import 'package:mute_around/features/setup/domain/entities/virtual_mic_status.dart';
import 'package:mute_around/features/setup/domain/usecases/check_readiness.dart';
import 'package:mute_around/features/setup/domain/usecases/install_virtual_mic.dart';
import 'package:mute_around/features/setup/domain/usecases/open_mic_privacy_settings.dart';
import 'package:mute_around/features/setup/domain/usecases/open_virtual_mic_download.dart';
import 'package:mute_around/features/setup/domain/usecases/report_mic_permission_denied.dart';
import 'package:mute_around/features/setup/domain/usecases/request_mic_permission.dart';
import 'package:mute_around/features/setup/presentation/bloc/setup_cubit.dart';

class MockCheckReadiness extends Mock implements CheckReadiness {}

class MockInstall extends Mock implements InstallVirtualMic {}

class MockRequest extends Mock implements RequestMicPermission {}

class MockOpenSettings extends Mock implements OpenMicPrivacySettings {}

class MockOpenDownload extends Mock implements OpenVirtualMicDownload {}

class MockReportDenied extends Mock implements ReportMicPermissionDenied {}

const ready = Readiness(
  platform: .macos,
  virtualMic: VirtualMicStatus.ready('sink'),
  permission: .granted,
);
const missingMic = Readiness(
  platform: .macos,
  virtualMic: VirtualMicStatus.notInstalled(.macos),
  permission: .granted,
);
const notAsked = Readiness(
  platform: .macos,
  virtualMic: VirtualMicStatus.ready('sink'),
  permission: .notDetermined,
);

void main() {
  late MockCheckReadiness check;
  late MockInstall install;
  late MockRequest request;
  late MockOpenSettings openSettings;
  late MockOpenDownload openDownload;
  late MockReportDenied reportDenied;
  late List<Readiness> answers;

  setUp(() {
    check = MockCheckReadiness();
    install = MockInstall();
    request = MockRequest();
    openSettings = MockOpenSettings();
    openDownload = MockOpenDownload();
    reportDenied = MockReportDenied();
    answers = [ready];
    // Each check returns the next answer; the last one repeats.
    when(() => check(retryDenied: any(named: 'retryDenied'))).thenAnswer(
      (_) async => answers.length > 1 ? answers.removeAt(0) : answers.first,
    );
    when(() => reportDenied()).thenReturn(null);
  });

  SetupCubit build({Duration poll = const Duration(hours: 1)}) => SetupCubit(
    check,
    install,
    request,
    openSettings,
    openDownload,
    reportDenied,
    pollInterval: poll,
  );

  blocTest<SetupCubit, SetupState>(
    'first check: ready',
    build: build,
    act: (c) => c.recheck(),
    expect: () => [const SetupState(readiness: ready)],
    verify: (c) {
      expect(c.state.isReady, isTrue);
      // ignore: avoid_redundant_argument_values — the cubit passes it explicitly, and mocktail matches named arguments exactly.
      verify(() => check(retryDenied: false)).called(1);
    },
  );

  blocTest<SetupCubit, SetupState>(
    'missing virtual mic: not ready',
    setUp: () => answers = [missingMic],
    build: build,
    act: (c) => c.recheck(),
    expect: () => [const SetupState(readiness: missingMic)],
    verify: (c) => expect(c.state.isReady, isFalse),
  );

  blocTest<SetupCubit, SetupState>(
    '"Check again" and resume forget a reported denial',
    build: build,
    act: (c) async {
      await c.recheck(userInitiated: true);
      await c.appResumed();
    },
    verify: (_) => verify(() => check(retryDenied: true)).called(2),
  );

  test('polls until the virtual mic appears, and keeps polling', () {
    fakeAsync((async) {
      answers = [missingMic, missingMic, ready];
      final cubit = build(poll: const Duration(seconds: 2));
      unawaited(cubit.recheck());
      async.flushMicrotasks();
      expect(cubit.state.isReady, isFalse);
      async.elapse(const Duration(seconds: 2));
      expect(cubit.state.isReady, isFalse);
      async.elapse(const Duration(seconds: 2));
      expect(cubit.state.isReady, isTrue);
      // Still watching, so a removed virtual mic is noticed.
      answers = [missingMic];
      async.elapse(const Duration(seconds: 2));
      expect(cubit.state.isReady, isFalse);
      unawaited(cubit.close());
      async.flushMicrotasks();
    });
  });

  blocTest<SetupCubit, SetupState>(
    'install: busy, then re-check',
    setUp: () {
      answers = [missingMic, ready];
      when(() => install()).thenAnswer((_) async => const Ok(unit));
    },
    build: build,
    act: (c) async {
      await c.recheck();
      await c.installVirtualMic();
    },
    expect: () => [
      const SetupState(readiness: missingMic),
      const SetupState(readiness: missingMic, activity: .installing),
      const SetupState(readiness: missingMic),
      const SetupState(readiness: ready),
    ],
  );

  blocTest<SetupCubit, SetupState>(
    'install cancelled by the user: no error shown',
    setUp: () {
      answers = [missingMic];
      when(
        () => install(),
      ).thenAnswer((_) async => const Err(UserCancelled()));
    },
    build: build,
    seed: () => const SetupState(readiness: missingMic),
    act: (c) => c.installVirtualMic(),
    expect: () => [
      const SetupState(readiness: missingMic, activity: .installing),
      const SetupState(readiness: missingMic),
    ],
  );

  blocTest<SetupCubit, SetupState>(
    'install failure is shown',
    setUp: () {
      answers = [missingMic];
      when(
        () => install(),
      ).thenAnswer((_) async => const Err(InstallFailure('x')));
    },
    build: build,
    seed: () => const SetupState(readiness: missingMic),
    act: (c) => c.installVirtualMic(),
    expect: () => [
      const SetupState(readiness: missingMic, activity: .installing),
      const SetupState(readiness: missingMic, failure: InstallFailure('x')),
    ],
  );

  blocTest<SetupCubit, SetupState>(
    'grant permission: prompt, then ready',
    setUp: () {
      answers = [ready];
      when(
        () => request(),
      ).thenAnswer((_) async => const Ok(MicPermission.granted));
    },
    build: build,
    seed: () => const SetupState(readiness: notAsked),
    act: (c) => c.requestPermission(),
    expect: () => [
      const SetupState(readiness: notAsked, activity: .requestingPermission),
      const SetupState(readiness: notAsked),
      const SetupState(readiness: ready),
    ],
  );

  blocTest<SetupCubit, SetupState>(
    'a link that fails to open is shown',
    setUp: () => when(
      () => openDownload(),
    ).thenAnswer((_) async => const Err(UnknownFailure('no browser'))),
    build: build,
    act: (c) => c.openVirtualMicDownload(),
    expect: () => [const SetupState(failure: UnknownFailure('no browser'))],
  );

  blocTest<SetupCubit, SetupState>(
    'engine refused the mic: report it, then re-check',
    build: build,
    act: (c) => c.engineReportedPermissionDenied(),
    verify: (_) {
      verifyInOrder([
        () => reportDenied(),
        // ignore: avoid_redundant_argument_values — see above.
        () => check(retryDenied: false),
      ]);
    },
  );
}

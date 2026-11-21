import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mute_around/core/failures.dart';
import 'package:mute_around/core/platform.dart';
import 'package:mute_around/features/setup/domain/entities/mic_permission.dart';
import 'package:mute_around/features/setup/domain/entities/readiness.dart';
import 'package:mute_around/features/setup/domain/entities/virtual_mic_status.dart';
import 'package:mute_around/features/setup/presentation/bloc/setup_cubit.dart';
import 'package:mute_around/features/setup/presentation/pages/setup_page.dart';

class MockSetupCubit extends MockCubit<SetupState> implements SetupCubit {}

void main() {
  late MockSetupCubit cubit;

  setUp(() {
    cubit = MockSetupCubit();
    when(() => cubit.installVirtualMic()).thenAnswer((_) async {});
    when(() => cubit.requestPermission()).thenAnswer((_) async {});
    when(() => cubit.openPrivacySettings()).thenAnswer((_) async {});
    when(() => cubit.openVirtualMicDownload()).thenAnswer((_) async {});
    when(
      () => cubit.recheck(userInitiated: any(named: 'userInitiated')),
    ).thenAnswer((_) async {});
  });

  Future<void> pump(
    WidgetTester tester,
    HostPlatform platform,
    SetupState state,
  ) async {
    when(() => cubit.state).thenReturn(state);
    await tester.pumpWidget(
      RepositoryProvider.value(
        value: HostInfo(platform),
        child: BlocProvider<SetupCubit>.value(
          value: cubit,
          child: const MaterialApp(home: SetupPage()),
        ),
      ),
    );
  }

  SetupState state(
    HostPlatform platform, {
    VirtualMicStatus? mic,
    MicPermission permission = .granted,
    SetupActivity activity = .idle,
    Failure? failure,
  }) => SetupState(
    readiness: Readiness(
      platform: platform,
      virtualMic: mic ?? VirtualMicStatus.notInstalled(platform),
      permission: permission,
    ),
    activity: activity,
    failure: failure,
  );

  testWidgets('spinner before the first check', (tester) async {
    await pump(tester, .macos, const SetupState());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  group('macOS', () {
    testWidgets('install button runs the installer', (tester) async {
      await pump(tester, .macos, state(.macos));
      await tester.tap(find.text('Install Mute Around microphone'));
      verify(() => cubit.installVirtualMic()).called(1);
      expect(find.text('Download VB-CABLE'), findsNothing);
    });

    testWidgets('install button is disabled while installing', (tester) async {
      await pump(tester, .macos, state(.macos, activity: .installing));
      await tester.tap(find.text('Install Mute Around microphone'));
      verifyNever(() => cubit.installVirtualMic());
    });

    testWidgets('not asked yet: Grant access prompts', (tester) async {
      await pump(
        tester,
        .macos,
        state(
          .macos,
          mic: const .ready('sink'),
          permission: .notDetermined,
        ),
      );
      await tester.tap(find.text('Grant access'));
      verify(() => cubit.requestPermission()).called(1);
      expect(find.text('The Mute Around microphone is installed.'), findsOne);
    });

    testWidgets('denied: explains and opens privacy settings', (tester) async {
      await pump(tester, .macos, state(.macos, permission: .denied));
      expect(find.textContaining('Privacy & Security'), findsOneWidget);
      await tester.tap(find.text('Open privacy settings'));
      verify(() => cubit.openPrivacySettings()).called(1);
    });

    testWidgets('shows an install failure in plain language', (tester) async {
      await pump(
        tester,
        .macos,
        state(.macos, failure: const InstallFailure('cp')),
      );
      expect(find.textContaining('could not be installed'), findsOneWidget);
    });
  });

  group('Windows', () {
    testWidgets('VB-CABLE explanation, download link, check again', (
      tester,
    ) async {
      await pump(
        tester,
        .windows,
        state(.windows, permission: .notDetermined),
      );
      expect(find.textContaining('VB-CABLE, a free virtual'), findsOneWidget);
      expect(find.text('Install Mute Around microphone'), findsNothing);
      // notDetermined is fine on Windows.
      expect(find.textContaining('Windows asks when'), findsOneWidget);
      await tester.tap(find.text('Download VB-CABLE'));
      verify(() => cubit.openVirtualMicDownload()).called(1);
      await tester.tap(find.text('Check again'));
      verify(() => cubit.recheck(userInitiated: true)).called(1);
    });

    testWidgets('denied: points to Windows privacy settings', (tester) async {
      await pump(
        tester,
        .windows,
        state(.windows, mic: const .ready('cable'), permission: .denied),
      );
      expect(find.textContaining('Settings → Privacy'), findsOneWidget);
      expect(find.text('VB-CABLE is installed.'), findsOneWidget);
    });
  });

  testWidgets('accessibility: labelled tap targets, enough contrast', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester, .macos, state(.macos, permission: .notDetermined));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });
}

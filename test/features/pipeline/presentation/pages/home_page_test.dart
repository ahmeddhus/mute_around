import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mute_around/core/failures.dart';
import 'package:mute_around/core/platform.dart';
import 'package:mute_around/features/pipeline/domain/entities/audio_levels.dart';
import 'package:mute_around/features/pipeline/domain/entities/input_device.dart';
import 'package:mute_around/features/pipeline/domain/entities/pipeline_status.dart';
import 'package:mute_around/features/pipeline/presentation/bloc/levels_cubit.dart';
import 'package:mute_around/features/pipeline/presentation/bloc/pipeline_bloc.dart';
import 'package:mute_around/features/pipeline/presentation/pages/home_page.dart';
import 'package:mute_around/features/pipeline/presentation/widgets/input_device_dropdown.dart';
import 'package:mute_around/features/pipeline/presentation/widgets/status_banner.dart';

class MockPipelineBloc extends MockBloc<PipelineEvent, PipelineState>
    implements PipelineBloc {}

class MockLevelsCubit extends MockCubit<AudioLevels> implements LevelsCubit {}

void main() {
  late MockPipelineBloc bloc;
  late MockLevelsCubit levels;

  setUpAll(() => registerFallbackValue(const PipelineEvent.retryRequested()));

  setUp(() {
    bloc = MockPipelineBloc();
    levels = MockLevelsCubit();
    when(() => levels.state).thenReturn(AudioLevels.silent);
  });

  Future<void> pump(
    WidgetTester tester,
    PipelineStatus status, {
    HostPlatform platform = .macos,
    PipelineState? state,
  }) async {
    // Tall enough that the whole (lazy) list is built.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    when(
      () => bloc.state,
    ).thenReturn(state ?? PipelineState(status: status));
    await tester.pumpWidget(
      RepositoryProvider.value(
        value: HostInfo(platform),
        child: MultiBlocProvider(
          providers: [
            BlocProvider<PipelineBloc>.value(value: bloc),
            BlocProvider<LevelsCubit>.value(value: levels),
          ],
          child: const MaterialApp(home: HomePage()),
        ),
      ),
    );
  }

  final banners = <PipelineStatus, String>{
    const PipelineStatus.starting(): 'Starting…',
    const PipelineStatus.processing(): 'Processing',
    const PipelineStatus.bypassed(.user): 'Bypassed',
    const PipelineStatus.bypassed(.overload): 'Bypassed — computer too busy',
    const PipelineStatus.deviceDisconnected('usb'): 'Microphone disconnected',
    const PipelineStatus.noInputDevice(): 'No microphone',
    const PipelineStatus.setupRequired(): 'Setup needed',
    const PipelineStatus.permissionNeeded(): 'Microphone access needed',
    const PipelineStatus.engineError(UnknownFailure()): 'Something went wrong',
  };
  for (final MapEntry(key: status, value: text) in banners.entries) {
    testWidgets('banner shows "$text" for $status', (tester) async {
      await pump(tester, status);
      expect(
        find.descendant(
          of: find.byType(StatusBanner),
          matching: find.text(text),
        ),
        findsOneWidget,
      );
    });
  }

  testWidgets('macOS hint names Mute Around', (tester) async {
    await pump(tester, const PipelineStatus.processing());
    expect(
      find.textContaining(
        'choose Mute Around as the microphone',
        findRichText: true,
      ),
      findsOneWidget,
    );
  });

  testWidgets('Windows hint names CABLE Output', (tester) async {
    await pump(tester, const PipelineStatus.processing(), platform: .windows);
    expect(
      find.textContaining(
        'choose CABLE Output as the microphone',
        findRichText: true,
      ),
      findsOneWidget,
    );
  });

  testWidgets('no Try again while processing', (tester) async {
    await pump(tester, const PipelineStatus.processing());
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('Try again on an engine error retries', (tester) async {
    await pump(tester, const PipelineStatus.engineError(DeviceFailure()));
    await tester.ensureVisible(find.text('Try again'));
    await tester.tap(find.text('Try again'));
    verify(() => bloc.add(const PipelineEvent.retryRequested())).called(1);
  });

  testWidgets('engine error explains in plain language', (tester) async {
    await pump(tester, const PipelineStatus.engineError(DeviceFailure('x')));
    expect(find.text("The microphone couldn't be opened"), findsOneWidget);
  });

  testWidgets('setup needed offers Open setup', (tester) async {
    await pump(tester, const PipelineStatus.setupRequired());
    expect(find.text('Open setup'), findsOneWidget);
  });

  testWidgets('picking a microphone sends inputSelected', (tester) async {
    await pump(
      tester,
      const PipelineStatus.processing(),
      state: PipelineState(
        status: const PipelineStatus.processing(),
        devices: [
          InputDevice(id: 'builtin', name: 'MacBook Mic'),
          InputDevice(id: 'usb', name: 'USB Mic'),
        ],
        selectedDeviceId: 'builtin',
      ),
    );
    await tester.tap(find.text('MacBook Mic'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('USB Mic').last);
    await tester.pumpAndSettle();
    verify(
      () => bloc.add(const PipelineEvent.inputSelected('usb')),
    ).called(1);
  });

  testWidgets('controls send bypass, strength and auto-gain events', (
    tester,
  ) async {
    await pump(tester, const PipelineStatus.processing());
    await tester.tap(find.text('Bypass (hear raw mic)'));
    await tester.tap(find.text('High'));
    await tester.tap(find.text('Auto gain'));
    verify(
      () => bloc.add(const PipelineEvent.bypassToggled(enabled: true)),
    ).called(1);
    verify(
      () => bloc.add(const PipelineEvent.strengthChanged(.high)),
    ).called(1);
    verify(
      () => bloc.add(const PipelineEvent.agcToggled(enabled: false)),
    ).called(1);
  });

  testWidgets('a failed control change is shown', (tester) async {
    await pump(
      tester,
      const PipelineStatus.processing(),
      state: const PipelineState(
        status: PipelineStatus.processing(),
        controlFailure: UnknownFailure('disk'),
      ),
    );
    expect(find.text('disk'), findsOneWidget);
  });

  group('accessibility', () {
    testWidgets('tap targets are labelled and text has enough contrast', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        const PipelineStatus.processing(),
        state: PipelineState(
          status: const PipelineStatus.processing(),
          devices: [InputDevice(id: 'builtin', name: 'MacBook Mic')],
          selectedDeviceId: 'builtin',
        ),
      );
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });

    testWidgets('every control is reachable with the keyboard', (
      tester,
    ) async {
      await pump(
        tester,
        const PipelineStatus.processing(),
        state: PipelineState(
          status: const PipelineStatus.processing(),
          devices: [InputDevice(id: 'builtin', name: 'MacBook Mic')],
          selectedDeviceId: 'builtin',
        ),
      );
      final visited = <FocusNode>{};
      var reachedMicrophone = false;
      for (var i = 0; i < 16; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final node = FocusManager.instance.primaryFocus;
        if (node == null) continue;
        visited.add(node);
        reachedMicrophone |=
            node.context
                ?.findAncestorWidgetOfExactType<InputDeviceDropdown>() !=
            null;
      }
      // About, microphone, Bypass, Low/Medium/High, Auto gain.
      expect(visited.length, greaterThanOrEqualTo(7));
      expect(reachedMicrophone, isTrue);
    });
  });
}

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mute_around/app/tray/tray_controller.dart';
import 'package:mute_around/app/tray/tray_host.dart';
import 'package:mute_around/features/pipeline/domain/entities/pipeline_status.dart';
import 'package:mute_around/features/pipeline/presentation/bloc/pipeline_bloc.dart';

class MockPipelineBloc extends MockBloc<PipelineEvent, PipelineState>
    implements PipelineBloc {}

/// Records what the controller shows and lets the test click the menu.
class FakeTrayHost implements TrayHost {
  final shown = <TrayMenuState>[];
  late void Function() toggleBypass;
  late void Function() open;
  late void Function() quit;
  bool disposed = false;

  @override
  void show({
    required TrayMenuState initial,
    required void Function() onToggleBypass,
    required void Function() onOpen,
    required void Function() onQuit,
  }) {
    shown.add(initial);
    toggleBypass = onToggleBypass;
    open = onOpen;
    quit = onQuit;
  }

  @override
  void update(TrayMenuState state) => shown.add(state);

  @override
  void dispose() => disposed = true;
}

void main() {
  late MockPipelineBloc bloc;
  late StreamController<PipelineState> states;
  late FakeTrayHost host;
  late int opened;
  late int quit;
  late TrayController controller;

  setUpAll(() => registerFallbackValue(const PipelineEvent.retryRequested()));

  setUp(() {
    bloc = MockPipelineBloc();
    states = StreamController.broadcast();
    host = FakeTrayHost();
    opened = 0;
    quit = 0;
    whenListen(
      bloc,
      states.stream,
      initialState: const PipelineState(status: PipelineStatus.processing()),
    );
    controller = TrayController(
      host: host,
      pipeline: bloc,
      onOpen: () => opened++,
      onQuit: () => quit++,
    )..start();
  });

  tearDown(() async {
    await controller.dispose();
    await states.close();
  });

  Future<void> emit(PipelineState s) async {
    when(() => bloc.state).thenReturn(s);
    states.add(s);
    await Future<void>.delayed(Duration.zero);
  }

  test('shows the status line and an unchecked, enabled Bypass', () {
    final m = host.shown.single;
    expect(m.status, 'Processing');
    expect(m.bypassChecked, isFalse);
    expect(m.bypassEnabled, isTrue);
  });

  test('status → menu labels, bypass item checked state', () async {
    await emit(
      const PipelineState(
        status: PipelineStatus.bypassed(.user),
        userBypass: true,
      ),
    );
    await emit(
      const PipelineState(status: PipelineStatus.bypassed(.overload)),
    );
    await emit(
      const PipelineState(status: PipelineStatus.deviceDisconnected('usb')),
    );
    expect(host.shown.map((m) => m.status), [
      'Processing',
      'Bypassed',
      'Bypassed — computer too busy',
      'Microphone disconnected',
    ]);
    expect(host.shown[1].bypassChecked, isTrue);
    // Nothing flowing: bypass would have no effect.
    expect(host.shown.last.bypassEnabled, isFalse);
  });

  test('unchanged menus are not pushed again', () async {
    await emit(const PipelineState(status: PipelineStatus.processing()));
    expect(host.shown, hasLength(1));
  });

  test('Bypass toggles the user bypass', () async {
    host.toggleBypass();
    verify(
      () => bloc.add(const PipelineEvent.bypassToggled(enabled: true)),
    ).called(1);
    await emit(
      const PipelineState(
        status: PipelineStatus.bypassed(.user),
        userBypass: true,
      ),
    );
    host.toggleBypass();
    verify(
      () => bloc.add(const PipelineEvent.bypassToggled(enabled: false)),
    ).called(1);
  });

  test('Open and Quit call through (Quit = the app exit handler)', () {
    host
      ..open()
      ..quit();
    expect(opened, 1);
    expect(quit, 1);
  });

  test('dispose removes the icon', () async {
    await controller.dispose();
    expect(host.disposed, isTrue);
  });
}

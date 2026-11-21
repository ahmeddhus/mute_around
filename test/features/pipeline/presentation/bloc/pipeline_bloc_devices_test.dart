import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mute_around/core/failures.dart';
import 'package:mute_around/core/result.dart';
import 'package:mute_around/features/pipeline/domain/entities/input_device_snapshot.dart';
import 'package:mute_around/features/pipeline/domain/entities/pipeline_status.dart';
import 'package:mute_around/features/pipeline/presentation/bloc/pipeline_bloc.dart';
import 'package:mute_around/features/settings/domain/entities/processing_settings.dart';

import 'pipeline_bloc_harness.dart';

void main() {
  late PipelineHarness h;

  setUp(() => h = PipelineHarness());
  tearDown(() => h.dispose());

  Future<void> poll(InputDeviceSnapshot s) async {
    h.devices.add(s);
    await settle();
  }

  blocTest<PipelineBloc, PipelineState>(
    'device polls update the list',
    build: () => h.build(),
    act: (bloc) async {
      await startReady(bloc);
      await poll(snapshot(['builtin', 'usb']));
    },
    verify: (bloc) {
      expect(bloc.state.devices.map((d) => d.id), ['builtin', 'usb']);
      verifyNever(
        () => h.selectDevice(any(), remember: any(named: 'remember')),
      );
    },
  );

  blocTest<PipelineBloc, PipelineState>(
    'select device: switches live and remembers it',
    build: () => h.build(),
    act: (bloc) async {
      await startReady(bloc);
      bloc.add(const PipelineEvent.inputSelected('usb'));
    },
    skip: 2,
    expect: () => [
      const PipelineState(
        status: PipelineStatus.processing(),
        selectedDeviceId: 'usb',
      ),
    ],
    verify: (_) => verify(() => h.selectDevice('usb')).called(1),
  );

  blocTest<PipelineBloc, PipelineState>(
    'select device that fails to open → DeviceDisconnected(id)',
    setUp: () => when(
      () => h.selectDevice('usb'),
    ).thenAnswer((_) async => const Err(DeviceFailure('busy'))),
    build: () => h.build(),
    act: (bloc) async {
      await startReady(bloc);
      bloc.add(const PipelineEvent.inputSelected('usb'));
    },
    skip: 2,
    expect: () => [hasStatus(const PipelineStatus.deviceDisconnected('usb'))],
  );

  blocTest<PipelineBloc, PipelineState>(
    'device lost → DeviceDisconnected; it returns → switched back → Processing',
    setUp: () {
      h.settings = const ProcessingSettings(inputDeviceId: 'usb');
      h.startedWith = 'usb';
    },
    build: () => h.build(),
    act: (bloc) async {
      await startReady(bloc);
      h.engineStatus.add(const PipelineStatus.deviceDisconnected('usb'));
      await settle();
      await poll(
        snapshot(
          ['builtin'],
          disconnected: ['usb'],
          removed: {'usb'},
        ),
      );
      await poll(snapshot(['builtin', 'usb']));
    },
    verify: (bloc) {
      expect(bloc.state.status, const PipelineStatus.processing());
      expect(bloc.state.selectedDeviceId, 'usb');
      // Only the return switches; recovery doesn't re-save the choice.
      verify(() => h.selectDevice('usb', remember: false)).called(1);
      verifyNever(
        () => h.selectDevice('builtin', remember: any(named: 'remember')),
      );
    },
  );

  blocTest<PipelineBloc, PipelineState>(
    'still listed but stopped (Bluetooth profile switch): retried each poll',
    setUp: () {
      var attempts = 0;
      when(
        () => h.selectDevice('builtin', remember: false),
      ).thenAnswer(
        (_) async => attempts++ == 0
            ? const Err(DeviceFailure('reconfiguring'))
            : const Ok(unit),
      );
    },
    build: () => h.build(),
    act: (bloc) async {
      await startReady(bloc);
      h.engineStatus.add(const PipelineStatus.deviceDisconnected('builtin'));
      await settle();
      await poll(snapshot(['builtin']));
      expect(
        bloc.state.status,
        const PipelineStatus.deviceDisconnected('builtin'),
      );
      await poll(snapshot(['builtin']));
    },
    verify: (bloc) {
      expect(bloc.state.status, const PipelineStatus.processing());
      verify(() => h.selectDevice('builtin', remember: false)).called(2);
    },
  );

  blocTest<PipelineBloc, PipelineState>(
    'empty list → NoInputDevice; a mic appears → it is used → Processing',
    build: () => h.build(),
    act: (bloc) async {
      await startReady(bloc);
      h.engineStatus.add(const PipelineStatus.deviceDisconnected('builtin'));
      await settle();
      await poll(
        snapshot(
          [],
          disconnected: ['builtin'],
          removed: {'builtin'},
        ),
      );
      expect(bloc.state.status, const PipelineStatus.noInputDevice());
      // The engine's own "disconnected" doesn't replace "no microphone".
      h.engineStatus.add(const PipelineStatus.deviceDisconnected('builtin'));
      await settle();
      expect(bloc.state.status, const PipelineStatus.noInputDevice());
      await poll(
        snapshot(['headset'], added: {'headset'}),
      );
    },
    verify: (bloc) {
      expect(bloc.state.status, const PipelineStatus.processing());
      expect(bloc.state.selectedDeviceId, 'headset');
      verify(() => h.selectDevice('headset', remember: false)).called(1);
    },
  );

  blocTest<PipelineBloc, PipelineState>(
    'no mic at launch → NoInputDevice; one appears → engine starts',
    setUp: () {
      var attempts = 0;
      when(() => h.start()).thenAnswer(
        (_) async =>
            attempts++ == 0 ? const Err(DeviceNotFound()) : const Ok('headset'),
      );
    },
    build: () => h.build(),
    act: (bloc) async {
      await startReady(bloc);
      await poll(snapshot([]));
      await poll(
        snapshot(['headset'], added: {'headset'}),
      );
    },
    verify: (bloc) {
      expect(bloc.state.status, const PipelineStatus.processing());
      expect(bloc.state.selectedDeviceId, 'headset');
      verify(() => h.start()).called(2);
    },
  );

  blocTest<PipelineBloc, PipelineState>(
    'the saved mic is missing at launch → started on the OS default',
    setUp: () => h
      ..settings = const ProcessingSettings(inputDeviceId: 'usb')
      ..startedWith = 'builtin',
    build: () => h.build(),
    act: (bloc) async {
      await startReady(bloc);
      await poll(
        snapshot(['builtin'], disconnected: ['usb']),
      );
    },
    verify: (bloc) {
      expect(bloc.state.selectedDeviceId, 'builtin');
      expect(bloc.state.status, const PipelineStatus.processing());
      // usb is still the user's choice; nothing switches until it's back.
      verifyNever(
        () => h.selectDevice(any(), remember: any(named: 'remember')),
      );
    },
  );

  blocTest<PipelineBloc, PipelineState>(
    'picking a mic while stopped saves it and starts',
    setUp: () {
      var attempts = 0;
      when(() => h.start()).thenAnswer(
        (_) async =>
            attempts++ == 0 ? const Err(DeviceNotFound()) : const Ok('usb'),
      );
    },
    build: () => h.build(),
    act: (bloc) async {
      await startReady(bloc);
      bloc.add(const PipelineEvent.inputSelected('usb'));
      await settle();
    },
    verify: (bloc) {
      verify(() => h.updateSettings(any())).called(1);
      verify(() => h.start()).called(2);
      expect(bloc.state.status, const PipelineStatus.processing());
    },
  );

  blocTest<PipelineBloc, PipelineState>(
    'device polls before setup is ready never start anything',
    build: () => h.build(),
    act: (bloc) async {
      bloc.add(const PipelineEvent.readinessChanged(ready: false));
      await settle();
      await poll(snapshot(['builtin']));
    },
    verify: (_) => verifyNever(() => h.start()),
  );
}

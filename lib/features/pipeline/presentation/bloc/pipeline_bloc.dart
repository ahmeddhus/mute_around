import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:mute_around/core/failures.dart';
import 'package:mute_around/core/result.dart';
import 'package:mute_around/features/pipeline/domain/entities/input_device.dart';
import 'package:mute_around/features/pipeline/domain/entities/input_device_snapshot.dart';
import 'package:mute_around/features/pipeline/domain/entities/pipeline_status.dart';
import 'package:mute_around/features/pipeline/domain/usecases/select_input_device.dart';
import 'package:mute_around/features/pipeline/domain/usecases/set_agc_enabled.dart';
import 'package:mute_around/features/pipeline/domain/usecases/set_bypass.dart';
import 'package:mute_around/features/pipeline/domain/usecases/set_strength.dart';
import 'package:mute_around/features/pipeline/domain/usecases/start_pipeline.dart';
import 'package:mute_around/features/pipeline/domain/usecases/stop_pipeline.dart';
import 'package:mute_around/features/pipeline/domain/usecases/watch_input_devices.dart';
import 'package:mute_around/features/pipeline/domain/usecases/watch_pipeline_status.dart';
import 'package:mute_around/features/settings/domain/entities/processing_settings.dart';
import 'package:mute_around/features/settings/domain/usecases/load_settings.dart';
import 'package:mute_around/features/settings/domain/usecases/update_settings.dart';

part 'pipeline_bloc.freezed.dart';
part 'pipeline_event.dart';
part 'pipeline_state.dart';

/// Use cases the [PipelineBloc] depends on, grouped so the constructor stays
/// readable.
@injectable
class PipelineUseCases {
  const PipelineUseCases({
    required this.start,
    required this.stop,
    required this.watchStatus,
    required this.loadSettings,
    required this.updateSettings,
    required this.watchDevices,
    required this.selectDevice,
    required this.setAgc,
    required this.setBypass,
    required this.setStrength,
  });

  final StartPipeline start;
  final StopPipeline stop;
  final WatchPipelineStatus watchStatus;
  final LoadSettings loadSettings;
  final UpdateSettings updateSettings;
  final WatchInputDevices watchDevices;
  final SelectInputDevice selectDevice;
  final SetAgcEnabled setAgc;
  final SetBypass setBypass;
  final SetStrength setStrength;
}

/// Runs the voice pipeline for the whole app lifetime (app-scoped).
/// Processing starts automatically once setup
/// is ready, not when the bloc is created.
///
/// Start/stop, engine status, device polls and microphone switches are
/// handled one at a time, in order, so they can't interleave. The bypass,
/// auto-gain and strength toggles are handled as they come: they take effect
/// immediately and only their persistence is slow (debounced).
@injectable
class PipelineBloc extends Bloc<PipelineEvent, PipelineState> {
  PipelineBloc(this._uc) : super(const PipelineState()) {
    on<PipelineEvent>(_onLifecycleEvent, transformer: _sequential);
    on<AgcToggled>(_onAgcToggled);
    on<BypassToggled>(_onBypassToggled);
    on<StrengthChanged>(_onStrengthChanged);
  }

  final PipelineUseCases _uc;

  StreamSubscription<PipelineStatus>? _statusSubscription;
  StreamSubscription<InputDeviceSnapshot>? _devicesSubscription;

  /// Setup is ready (virtual mic + permission).
  bool _ready = false;

  /// The engine is running.
  bool _running = false;

  /// The microphone the user chose (saved in settings), which may differ
  /// from [PipelineState.selectedDeviceId] while it's unplugged.
  String? _preferredId;

  static Stream<E> _sequential<E>(Stream<E> events, EventMapper<E> mapper) =>
      events.asyncExpand(mapper);

  Future<void> _onLifecycleEvent(
    PipelineEvent event,
    Emitter<PipelineState> emit,
  ) => switch (event) {
    ReadinessChanged(:final ready) => _onReadinessChanged(ready, emit),
    RetryRequested() => _start(emit),
    EngineStatusChanged(:final status) => _onEngineStatus(status, emit),
    DevicesChanged(:final snapshot) => _onDevicesChanged(snapshot, emit),
    InputSelected(:final deviceId) => _onInputSelected(deviceId, emit),
    // Handled by their own handlers.
    AgcToggled() || BypassToggled() || StrengthChanged() => Future.value(),
  };

  Future<void> _onReadinessChanged(
    bool ready,
    Emitter<PipelineState> emit,
  ) async {
    _ready = ready;
    if (ready) return _start(emit);
    if (_running) {
      _running = false;
      await _uc.stop();
    }
    emit(state.copyWith(status: const PipelineStatus.setupRequired()));
  }

  Future<void> _start(Emitter<PipelineState> emit) async {
    if (_running || !_ready) return;
    emit(state.copyWith(status: const PipelineStatus.starting()));
    final settings =
        (await _uc.loadSettings()).valueOrNull ?? const ProcessingSettings();
    _preferredId = settings.inputDeviceId;
    emit(
      state.copyWith(
        userBypass: settings.userBypass,
        agcEnabled: settings.agcEnabled,
        strength: settings.strength,
      ),
    );
    _watchDevices();
    switch (await _uc.start()) {
      case Ok(:final value):
        _running = true;
        _statusSubscription ??= _uc.watchStatus().listen(
          (status) => add(PipelineEvent.engineStatusChanged(status)),
        );
        emit(state.copyWith(selectedDeviceId: value, status: _activeStatus));
      case Err(:final failure):
        emit(state.copyWith(status: _statusFor(failure)));
    }
  }

  void _watchDevices() {
    _devicesSubscription ??= _uc
        .watchDevices(selectedId: () => _preferredId ?? state.selectedDeviceId)
        .listen((snapshot) => add(PipelineEvent.devicesChanged(snapshot)));
  }

  Future<void> _onEngineStatus(
    PipelineStatus status,
    Emitter<PipelineState> emit,
  ) async {
    if (!_running) return;
    // "No microphone" says more than "disconnected" once the list is empty.
    if (status is DeviceDisconnected && state.status is NoInputDevice) return;
    emit(state.copyWith(status: status));
  }

  /// Device poll: keeps the list current and recovers on its own
  /// when the chosen microphone comes back, a stopped one (Bluetooth profile
  /// switch) works again, or a microphone appears after there was none.
  Future<void> _onDevicesChanged(
    InputDeviceSnapshot snapshot,
    Emitter<PipelineState> emit,
  ) async {
    emit(state.copyWith(devices: snapshot.devices));
    if (!_ready) return;
    final connected = snapshot.connected;
    bool isConnected(String? id) =>
        id != null && connected.any((d) => d.id == id);

    if (!_running) {
      if (state.status is NoInputDevice && connected.isNotEmpty) {
        await _start(emit);
      }
      return;
    }
    if (connected.isEmpty) {
      emit(state.copyWith(status: const PipelineStatus.noInputDevice()));
      return;
    }
    final inUse = state.selectedDeviceId;
    final lost =
        state.status is DeviceDisconnected || state.status is NoInputDevice;
    final String? target;
    if (isConnected(_preferredId) && (_preferredId != inUse || lost)) {
      // The chosen microphone is back (or never left but stopped).
      target = _preferredId;
    } else if (lost && isConnected(inUse)) {
      // Still listed but stopped, e.g. a Bluetooth headset that switched
      // to call mode: retry it on every poll until it works.
      target = inUse;
    } else if (state.status is NoInputDevice) {
      // A microphone appeared after there was none.
      target = fallbackInputDevice(connected).id;
    } else {
      // Disconnected and not back yet: wait, or let the user pick another.
      return;
    }
    await _switchTo(target!, emit, remember: false);
  }

  Future<void> _onInputSelected(
    String deviceId,
    Emitter<PipelineState> emit,
  ) async {
    _preferredId = deviceId;
    if (!_running) {
      // Nothing to switch: remember it and use it on the next start.
      final saved = await _uc.updateSettings(
        (s) => s.copyWith(inputDeviceId: deviceId),
      );
      emit(
        state.copyWith(
          selectedDeviceId: deviceId,
          controlFailure: saved.failureOrNull,
        ),
      );
      return _start(emit);
    }
    await _switchTo(deviceId, emit, remember: true);
  }

  /// Switches the running engine to [deviceId]. [remember]: the
  /// user picked it, so it's saved; automatic recovery doesn't save.
  Future<void> _switchTo(
    String deviceId,
    Emitter<PipelineState> emit, {
    required bool remember,
  }) async {
    final result = await _uc.selectDevice(deviceId, remember: remember);
    emit(
      state.copyWith(
        selectedDeviceId: deviceId,
        status: switch (result) {
          Ok() => _activeStatus,
          Err(:final failure) => switch (failure) {
            PermissionDenied() => const PipelineStatus.permissionNeeded(),
            DeviceNotFound() ||
            DeviceFailure() => PipelineStatus.deviceDisconnected(deviceId),
            _ => PipelineStatus.engineError(failure),
          },
        },
      ),
    );
  }

  Future<void> _onAgcToggled(
    AgcToggled event,
    Emitter<PipelineState> emit,
  ) async {
    final before = state.agcEnabled;
    emit(state.copyWith(agcEnabled: event.enabled, controlFailure: null));
    final result = await _uc.setAgc(enabled: event.enabled);
    if (result case Err(:final failure)) {
      emit(state.copyWith(agcEnabled: before, controlFailure: failure));
    }
  }

  Future<void> _onBypassToggled(
    BypassToggled event,
    Emitter<PipelineState> emit,
  ) async {
    final before = state.userBypass;
    emit(state.copyWith(userBypass: event.enabled, controlFailure: null));
    // Show the change right away; the engine status follows within a poll.
    if (state.isActive) emit(state.copyWith(status: _activeStatus));
    final result = await _uc.setBypass(enabled: event.enabled);
    if (result case Err(:final failure)) {
      emit(state.copyWith(userBypass: before, controlFailure: failure));
      if (state.isActive) emit(state.copyWith(status: _activeStatus));
    }
  }

  Future<void> _onStrengthChanged(
    StrengthChanged event,
    Emitter<PipelineState> emit,
  ) async {
    final before = state.strength;
    emit(state.copyWith(strength: event.strength, controlFailure: null));
    final result = await _uc.setStrength(event.strength);
    if (result case Err(:final failure)) {
      emit(state.copyWith(strength: before, controlFailure: failure));
    }
  }

  /// The status of a running engine with the current user bypass. An
  /// overload bypass is reported by the engine itself and never replaced by
  /// this guess unless the user turns their own bypass on.
  PipelineStatus get _activeStatus {
    if (state.userBypass) return const PipelineStatus.bypassed(.user);
    if (state.status case Bypassed(reason: .overload)) return state.status;
    return const PipelineStatus.processing();
  }

  static PipelineStatus _statusFor(Failure failure) => switch (failure) {
    VirtualMicMissing() => PipelineStatus.setupRequired(failure),
    PermissionDenied() => const PipelineStatus.permissionNeeded(),
    DeviceNotFound() => const PipelineStatus.noInputDevice(),
    _ => PipelineStatus.engineError(failure),
  };

  @override
  Future<void> close() async {
    await _statusSubscription?.cancel();
    await _devicesSubscription?.cancel();
    return super.close();
  }
}

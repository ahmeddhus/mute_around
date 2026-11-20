import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:injectable/injectable.dart';
import 'package:mute_around/core/audio/audio_device.dart';
import 'package:mute_around/core/failures.dart';
import 'package:mute_around/core/native/engine_errors.dart';
import 'package:mute_around/core/native/engine_library.dart';
import 'package:mute_around/core/native/mute_engine.ffigen.dart';
import 'package:mute_around/core/result.dart';
import 'package:mute_around/features/pipeline/data/datasources/engine_data_source.dart';
import 'package:mute_around/features/settings/domain/entities/processing_settings.dart';

/// [EngineDataSource] over the native engine through FFI.
///
/// The engine is created lazily on first use (loading the model takes a
/// moment) and owned by this object: [dispose] destroys it, and a
/// [NativeFinalizer] does so if this object is collected first.
@LazySingleton(as: EngineDataSource)
class FfiEngineDataSource implements EngineDataSource, Finalizable {
  FfiEngineDataSource({
    @ignoreParam this.modelPath,
    @ignoreParam this.visibleInterval = const Duration(milliseconds: 33),
    @ignoreParam this.hiddenInterval = const Duration(milliseconds: 250),
  });

  /// DFN model tarball; `null` uses the model embedded in the library.
  final String? modelPath;
  final Duration visibleInterval;
  final Duration hiddenInterval;

  static const _maxDevices = 64;

  Pointer<me_engine> _engine = nullptr;
  bool _disposed = false;
  bool _visible = true;
  Timer? _poll;
  EngineStatus? _lastStatus;

  late final StreamController<EngineStatus> _status =
      StreamController<EngineStatus>.broadcast(
        onListen: _restartPolling,
        onCancel: _stopPolling,
      );

  @override
  Stream<EngineStatus> get status => _status.stream;

  @override
  Result<List<AudioDevice>> listDevices(DeviceKind kind) =>
      _withEngine((engine) {
        return using((arena) {
          final buf = arena<me_device_info>(_maxDevices);
          final count = me_list_devices(
            engine,
            kind == DeviceKind.capture ? ME_DEVICE_CAPTURE : ME_DEVICE_PLAYBACK,
            buf,
            _maxDevices,
          );
          if (count < 0) return Err(_failure(engine, count));
          final n = count < _maxDevices ? count : _maxDevices;
          return Ok([
            for (var i = 0; i < n; i++)
              AudioDevice(
                id: readCString(buf[i].id, ME_DEVICE_ID_MAX),
                name: readCString(buf[i].name, ME_DEVICE_NAME_MAX),
                isDefault: buf[i].is_default != 0,
              ),
          ]);
        });
      });

  @override
  Result<Unit> start({String? captureId, String? sinkId}) =>
      _withEngine((engine) {
        return using((arena) {
          final r = me_engine_start(
            engine,
            captureId == null ? nullptr : toCString(captureId, arena),
            sinkId == null ? nullptr : toCString(sinkId, arena),
          );
          return r == ME_OK ? const Ok(unit) : Err(_failure(engine, r));
        });
      });

  @override
  Result<Unit> stop() => _withEngine((engine) {
    final r = me_engine_stop(engine);
    return r == ME_OK ? const Ok(unit) : Err(_failure(engine, r));
  });

  @override
  Result<Unit> setBypass({required bool enabled}) => _withEngine((engine) {
    me_set_bypass(engine, enabled ? 1 : 0);
    return const Ok(unit);
  });

  @override
  Result<Unit> setAgc({required bool enabled}) => _withEngine((engine) {
    me_set_agc(engine, enabled ? 1 : 0);
    return const Ok(unit);
  });

  @override
  Result<Unit> setStrength(SuppressionStrength strength) =>
      _withEngine((engine) {
        me_set_strength(engine, switch (strength) {
          .low => ME_STRENGTH_LOW,
          .medium => ME_STRENGTH_MEDIUM,
          .high => ME_STRENGTH_HIGH,
        });
        return const Ok(unit);
      });

  @override
  void setVisible({required bool visible}) {
    if (_visible == visible) return;
    _visible = visible;
    if (_poll != null) _restartPolling();
  }

  /// The current polling interval (for tests and diagnostics).
  Duration get pollInterval => _visible ? visibleInterval : hiddenInterval;

  @override
  @disposeMethod
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _stopPolling();
    await _status.close();
    if (_engine != nullptr) {
      engineFinalizer.detach(this);
      me_engine_destroy(_engine);
      _engine = nullptr;
    }
  }

  void _restartPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(pollInterval, (_) => _pollStatus());
    _pollStatus();
  }

  void _stopPolling() {
    _poll?.cancel();
    _poll = null;
  }

  void _pollStatus() {
    if (_engine == nullptr || _status.isClosed) return;
    final status = _statusFromNative(me_get_status(_engine));
    if (status != _lastStatus) {
      _lastStatus = status;
      _status.add(status);
    }
  }

  static EngineStatus _statusFromNative(int status) => switch (status) {
    ME_STATUS_STOPPED => .stopped,
    ME_STATUS_RUNNING => .running,
    ME_STATUS_BYPASSED_USER => .bypassedUser,
    ME_STATUS_BYPASSED_OVERLOAD => .bypassedOverload,
    ME_STATUS_DEVICE_DISCONNECTED => .deviceDisconnected,
    _ => .error,
  };

  /// Runs [body] with the engine, creating it first if needed. Native
  /// failures become [Err]s; nothing escapes as an exception.
  Result<T> _withEngine<T>(Result<T> Function(Pointer<me_engine>) body) {
    if (_disposed) {
      return const Err(EngineStateFailure('The engine was disposed'));
    }
    try {
      if (_engine == nullptr) {
        switch (_create()) {
          case Err(:final failure):
            return Err(failure);
          case Ok():
        }
      }
      return body(_engine);
    } on Object catch (e) {
      // ArgumentError when the native asset can't be found or loaded.
      return Err(UnknownFailure('Native engine call failed: $e'));
    }
  }

  Result<Unit> _create() {
    switch (checkEngineAbi()) {
      case Err(:final failure):
        return Err(failure);
      case Ok():
    }
    return using((arena) {
      final out = arena<Pointer<me_engine>>();
      final path = modelPath;
      final r = me_engine_create(
        path == null ? nullptr : toCString(path, arena),
        out,
      );
      if (r != ME_OK) {
        return Err(
          failureFromEngineResult(
            r,
            'Could not load the noise-suppression model',
          ),
        );
      }
      _engine = out.value;
      engineFinalizer.attach(this, _engine.cast(), detach: this);
      return const Ok(unit);
    });
  }

  Failure _failure(Pointer<me_engine> engine, int code) => using((arena) {
    const cap = 512;
    final buf = arena<Char>(cap);
    final detail = me_last_error(engine, buf, cap) == ME_OK
        ? buf.cast<Utf8>().toDartString()
        : '';
    return failureFromEngineResult(code, detail);
  });
}

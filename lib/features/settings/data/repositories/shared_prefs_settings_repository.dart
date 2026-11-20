import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:mute_around/core/failures.dart';
import 'package:mute_around/core/result.dart';
import 'package:mute_around/features/settings/domain/entities/processing_settings.dart';
import 'package:mute_around/features/settings/domain/repositories/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [SettingsRepository] backed by `shared_preferences`.
///
/// Writes are debounced by [debounce]: rapid changes (dragging through
/// presets, toggling quickly) produce one write with the latest values.
@LazySingleton(as: SettingsRepository)
class SharedPrefsSettingsRepository implements SettingsRepository {
  SharedPrefsSettingsRepository(
    this._prefs, {
    @ignoreParam this.debounce = const Duration(milliseconds: 300),
  });

  static const inputDeviceIdKey = 'input_device_id';
  static const userBypassKey = 'user_bypass';
  static const agcEnabledKey = 'agc_enabled';
  static const strengthKey = 'strength';

  final SharedPreferencesAsync _prefs;
  final Duration debounce;

  ProcessingSettings? _pending;
  Timer? _timer;
  Completer<Result<Unit>>? _pendingWrite;

  @override
  Future<Result<ProcessingSettings>> load() async {
    final pending = _pending;
    if (pending != null) return Ok(pending);
    try {
      const defaults = ProcessingSettings();
      final strengthName = await _prefs.getString(strengthKey);
      return Ok(
        ProcessingSettings(
          inputDeviceId: await _prefs.getString(inputDeviceIdKey),
          userBypass:
              await _prefs.getBool(userBypassKey) ?? defaults.userBypass,
          agcEnabled:
              await _prefs.getBool(agcEnabledKey) ?? defaults.agcEnabled,
          strength:
              SuppressionStrength.values.asNameMap()[strengthName] ??
              defaults.strength,
        ),
      );
    } on Object catch (e) {
      // A value stored with the wrong type throws; treat it as missing.
      if (e is TypeError) return const Ok(ProcessingSettings());
      return Err(UnknownFailure('Could not read settings: $e'));
    }
  }

  @override
  Future<Result<Unit>> save(ProcessingSettings settings) {
    _pending = settings;
    _timer?.cancel();
    _timer = Timer(debounce, _flush);
    return (_pendingWrite ??= Completer<Result<Unit>>()).future;
  }

  @override
  @disposeMethod
  Future<void> flush() async {
    if (_pending == null) return;
    _timer?.cancel();
    await _flush();
  }

  Future<void> _flush() async {
    final settings = _pending;
    final completer = _pendingWrite;
    _pending = null;
    _pendingWrite = null;
    _timer = null;
    if (settings == null || completer == null) return;
    completer.complete(await _write(settings));
  }

  Future<Result<Unit>> _write(ProcessingSettings settings) async {
    try {
      final deviceId = settings.inputDeviceId;
      await (deviceId == null
          ? _prefs.remove(inputDeviceIdKey)
          : _prefs.setString(inputDeviceIdKey, deviceId));
      await _prefs.setBool(userBypassKey, settings.userBypass);
      await _prefs.setBool(agcEnabledKey, settings.agcEnabled);
      await _prefs.setString(strengthKey, settings.strength.name);
      return const Ok(unit);
    } on Object catch (e) {
      return Err(UnknownFailure('Could not save settings: $e'));
    }
  }
}

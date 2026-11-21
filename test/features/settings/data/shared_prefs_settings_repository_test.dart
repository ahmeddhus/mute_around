import 'package:flutter_test/flutter_test.dart';
import 'package:mute_around/core/failures.dart';
import 'package:mute_around/core/result.dart';
import 'package:mute_around/features/settings/data/repositories/shared_prefs_settings_repository.dart';
import 'package:mute_around/features/settings/domain/entities/processing_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late FakeSharedPreferencesAsync prefs;
  late SharedPrefsSettingsRepository repository;

  setUp(() {
    prefs = FakeSharedPreferencesAsync();
    repository = SharedPrefsSettingsRepository(
      prefs,
      debounce: const Duration(milliseconds: 20),
    );
  });

  test('loads defaults when nothing is stored', () async {
    expect(await repository.load(), const Ok(ProcessingSettings()));
    const defaults = ProcessingSettings();
    expect(defaults.inputDeviceId, isNull);
    expect(defaults.userBypass, isFalse);
    expect(defaults.agcEnabled, isTrue);
    expect(defaults.strength, SuppressionStrength.medium);
  });

  test('round-trips every field', () async {
    const settings = ProcessingSettings(
      inputDeviceId: 'usb-mic',
      userBypass: true,
      agcEnabled: false,
      strength: .high,
    );
    expect(await repository.save(settings), const Ok(unit));
    expect(prefs.values, {
      'input_device_id': 'usb-mic',
      'user_bypass': true,
      'agc_enabled': false,
      'strength': 'high',
    });
    final fresh = SharedPrefsSettingsRepository(prefs);
    expect(await fresh.load(), const Ok(settings));
  });

  test('a null device id removes the stored key', () async {
    prefs.values['input_device_id'] = 'old';
    await repository.save(const ProcessingSettings());
    expect(prefs.values.containsKey('input_device_id'), isFalse);
  });

  test('unknown or corrupt values fall back to defaults', () async {
    prefs.values['strength'] = 'extreme';
    expect(await repository.load(), const Ok(ProcessingSettings()));

    prefs.values['agc_enabled'] = 'yes';
    expect(await repository.load(), const Ok(ProcessingSettings()));
  });

  test('debounces rapid saves into one write of the latest value', () async {
    final first = repository.save(const ProcessingSettings(strength: .low));
    final second = repository.save(const ProcessingSettings(strength: .high));
    expect(prefs.writes, 0);
    expect(
      await repository.load(),
      const Ok(ProcessingSettings(strength: .high)),
    );
    expect(await first, const Ok(unit));
    expect(await second, const Ok(unit));
    expect(prefs.values['strength'], 'high');
    // One flush writes the three non-null keys once.
    expect(prefs.writes, 3);
  });

  test('flush writes pending settings immediately', () async {
    final pending = repository.save(const ProcessingSettings(userBypass: true));
    await repository.flush();
    expect(prefs.values['user_bypass'], isTrue);
    expect(await pending, const Ok(unit));
  });

  test('a failed write returns Err', () async {
    prefs.failWrites = true;
    final result = await repository.save(const ProcessingSettings());
    expect(result, isA<Err<Unit>>());
    expect(result.failureOrNull, isA<UnknownFailure>());
  });

  test('concurrent updates are applied in order, none lost', () async {
    final a = repository.update((s) => s.copyWith(agcEnabled: false));
    final b = repository.update((s) => s.copyWith(strength: .low));
    final c = repository.update((s) => s.copyWith(userBypass: true));
    expect(await Future.wait([a, b, c]), everyElement(const Ok(unit)));
    expect(
      await repository.load(),
      const Ok(
        ProcessingSettings(agcEnabled: false, strength: .low, userBypass: true),
      ),
    );
    expect(prefs.values['agc_enabled'], false);
    expect(prefs.values['strength'], 'low');
    expect(prefs.values['user_bypass'], true);
  });
}

/// In-memory [SharedPreferencesAsync] for tests.
// ignore: must_be_immutable — a test fake that records writes.
class FakeSharedPreferencesAsync extends Fake
    implements SharedPreferencesAsync {
  final Map<String, Object> values = {};
  int writes = 0;
  bool failWrites = false;

  T? _get<T>(String key) {
    final value = values[key];
    if (value == null) return null;
    // Mirror the real plugin: a value of the wrong type is a TypeError.
    return value as T;
  }

  @override
  Future<String?> getString(String key) async => _get<String>(key);

  @override
  Future<bool?> getBool(String key) async => _get<bool>(key);

  @override
  Future<void> setString(String key, String value) async => _set(key, value);

  @override
  Future<void> setBool(String key, bool value) async => _set(key, value);

  @override
  Future<void> remove(String key) async {
    if (failWrites) throw StateError('disk full');
    values.remove(key);
  }

  void _set(String key, Object value) {
    if (failWrites) throw StateError('disk full');
    writes++;
    values[key] = value;
  }
}

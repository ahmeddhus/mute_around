import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mute_around/core/failures.dart';
import 'package:mute_around/core/result.dart';
import 'package:mute_around/features/settings/domain/entities/processing_settings.dart';
import 'package:mute_around/features/settings/domain/repositories/settings_repository.dart';
import 'package:mute_around/features/settings/domain/usecases/flush_settings.dart';
import 'package:mute_around/features/settings/domain/usecases/load_settings.dart';
import 'package:mute_around/features/settings/domain/usecases/save_settings.dart';
import 'package:mute_around/features/settings/domain/usecases/update_settings.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  late MockSettingsRepository repository;

  setUpAll(() {
    registerFallbackValue(const ProcessingSettings());
    registerFallbackValue((ProcessingSettings s) => s);
  });
  setUp(() => repository = MockSettingsRepository());

  test('LoadSettings returns what the repository loads', () async {
    const settings = ProcessingSettings(strength: .low);
    when(() => repository.load()).thenAnswer((_) async => const Ok(settings));
    expect(await LoadSettings(repository)(), const Ok(settings));
  });

  test('LoadSettings propagates Err', () async {
    when(
      () => repository.load(),
    ).thenAnswer((_) async => const Err(UnknownFailure()));
    expect(
      await LoadSettings(repository)(),
      const Err<ProcessingSettings>(UnknownFailure()),
    );
  });

  test('SaveSettings passes settings to the repository', () async {
    const settings = ProcessingSettings(agcEnabled: false);
    when(() => repository.save(any())).thenAnswer((_) async => const Ok(unit));
    expect(await SaveSettings(repository)(settings), const Ok(unit));
    verify(() => repository.save(settings)).called(1);
  });

  test('FlushSettings flushes the repository', () async {
    when(() => repository.flush()).thenAnswer((_) async {});
    await FlushSettings(repository)();
    verify(() => repository.flush()).called(1);
  });

  test('UpdateSettings passes the change to the repository', () async {
    ProcessingSettings Function(ProcessingSettings)? passed;
    when(() => repository.update(any())).thenAnswer((i) async {
      passed =
          i.positionalArguments.first
              as ProcessingSettings Function(ProcessingSettings);
      return const Ok(unit);
    });
    final result = await UpdateSettings(
      repository,
    )((s) => s.copyWith(agcEnabled: false));
    expect(result, const Ok(unit));
    expect(
      passed!(const ProcessingSettings(strength: .high)),
      const ProcessingSettings(strength: .high, agcEnabled: false),
    );
  });
}

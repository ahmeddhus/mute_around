import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mute_around/core/failures.dart';
import 'package:mute_around/core/result.dart';
import 'package:mute_around/features/settings/domain/entities/processing_settings.dart';
import 'package:mute_around/features/settings/domain/repositories/settings_repository.dart';
import 'package:mute_around/features/settings/domain/usecases/load_settings.dart';
import 'package:mute_around/features/settings/domain/usecases/save_settings.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  late MockSettingsRepository repository;

  setUpAll(() => registerFallbackValue(const ProcessingSettings()));
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
}

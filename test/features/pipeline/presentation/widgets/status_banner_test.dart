import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mute_around/features/pipeline/domain/entities/pipeline_status.dart';
import 'package:mute_around/features/pipeline/presentation/widgets/status_banner.dart';

void main() {
  testWidgets('announces status changes to screen readers', (tester) async {
    final announced = <String>[];
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
      SystemChannels.accessibility,
      (message) async {
        final data = (message as Map)['data'] as Map;
        announced.add(data['message'] as String);
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<dynamic>(
            SystemChannels.accessibility,
            null,
          ),
    );

    Future<void> show(PipelineStatus s) => tester.pumpWidget(
      MaterialApp(home: StatusBanner(status: s)),
    );
    await show(const PipelineStatus.processing());
    await show(const PipelineStatus.processing());
    await show(const PipelineStatus.bypassed(.overload));
    await show(const PipelineStatus.bypassed(.user));
    expect(announced, ['Bypassed — computer too busy', 'Bypassed']);
  });
}

import 'package:material_ui/material_ui.dart';

/// One step of the setup checklist: a ✓ or "action needed" marker, a title,
/// an explanation and the step's actions.
class SetupStep extends StatelessWidget {
  const SetupStep({
    super.key,
    required this.number,
    required this.title,
    required this.done,
    required this.description,
    this.actions = const [],
  });

  final int number;
  final String title;
  final bool done;
  final String description;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const .all(16),
        child: Row(
          crossAxisAlignment: .start,
          spacing: 16,
          children: [
            Semantics(
              label: done ? 'Done' : 'Action needed',
              child: CircleAvatar(
                backgroundColor: done
                    ? scheme.primaryContainer
                    : scheme.surfaceContainerHighest,
                child: done
                    ? Icon(Icons.check, color: scheme.onPrimaryContainer)
                    : ExcludeSemantics(child: Text('$number')),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                spacing: 8,
                children: [
                  Text(title, style: text.titleMedium),
                  Text(description, style: text.bodyMedium),
                  if (actions.isNotEmpty)
                    Wrap(spacing: 8, runSpacing: 8, children: actions),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

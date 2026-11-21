import 'dart:async';

import 'package:mute_around/app/tray/tray_host.dart';
import 'package:mute_around/features/pipeline/domain/entities/pipeline_status.dart';
import 'package:mute_around/features/pipeline/presentation/bloc/pipeline_bloc.dart';
import 'package:mute_around/features/pipeline/presentation/widgets/status_banner.dart';

/// The menu-bar / tray menu: a status line, a Bypass
/// checkbox, "Open Mute Around" and "Quit". Follows the app-scoped
/// [PipelineBloc] passed in by `app.dart`.
class TrayController {
  TrayController({
    required this._host,
    required this._pipeline,
    required this._onOpen,
    required this._onQuit,
  });

  final TrayHost _host;
  final PipelineBloc _pipeline;
  final void Function() _onOpen;
  final void Function() _onQuit;
  StreamSubscription<PipelineState>? _subscription;
  TrayMenuState? _last;

  /// What the menu shows for [state].
  static TrayMenuState menuFor(PipelineState state) => TrayMenuState(
    status: StatusBanner.label(state.status),
    bypassChecked: state.userBypass,
    // Bypass only means something while audio flows (or is about to).
    bypassEnabled: state.isActive || state.status is Starting,
  );

  void start() {
    _last = menuFor(_pipeline.state);
    _host.show(
      initial: _last!,
      onToggleBypass: () => _pipeline.add(
        PipelineEvent.bypassToggled(enabled: !_pipeline.state.userBypass),
      ),
      onOpen: _onOpen,
      onQuit: _onQuit,
    );
    _subscription = _pipeline.stream.listen((state) {
      final menu = menuFor(state);
      final last = _last;
      if (last != null &&
          last.status == menu.status &&
          last.bypassChecked == menu.bypassChecked &&
          last.bypassEnabled == menu.bypassEnabled) {
        return;
      }
      _last = menu;
      _host.update(menu);
    });
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _host.dispose();
  }
}

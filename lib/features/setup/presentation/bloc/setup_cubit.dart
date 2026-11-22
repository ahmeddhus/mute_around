import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:mute_around/core/failures.dart';
import 'package:mute_around/core/result.dart';
import 'package:mute_around/features/setup/domain/entities/readiness.dart';
import 'package:mute_around/features/setup/domain/usecases/check_readiness.dart';
import 'package:mute_around/features/setup/domain/usecases/install_virtual_mic.dart';
import 'package:mute_around/features/setup/domain/usecases/open_mic_privacy_settings.dart';
import 'package:mute_around/features/setup/domain/usecases/open_virtual_mic_download.dart';
import 'package:mute_around/features/setup/domain/usecases/report_mic_permission_denied.dart';
import 'package:mute_around/features/setup/domain/usecases/request_mic_permission.dart';

part 'setup_cubit.freezed.dart';
part 'setup_state.dart';

/// Whether the virtual mic and microphone permission are ready.
///
/// App-scoped, like `PipelineBloc`: the router redirect reads it and
/// `app.dart` forwards its readiness to the pipeline. After the first check
/// it re-checks every [pollInterval], so the app notices VB-CABLE being
/// installed or permission being granted on its own, and a
/// virtual mic removed later sends the user back to setup.
@injectable
class SetupCubit extends Cubit<SetupState> {
  SetupCubit(
    this._checkReadiness,
    this._installVirtualMic,
    this._requestMicPermission,
    this._openMicPrivacySettings,
    this._openVirtualMicDownload,
    this._reportMicPermissionDenied, {
    @ignoreParam this.pollInterval = const Duration(seconds: 2),
  }) : super(const SetupState());

  final CheckReadiness _checkReadiness;
  final InstallVirtualMic _installVirtualMic;
  final RequestMicPermission _requestMicPermission;
  final OpenMicPrivacySettings _openMicPrivacySettings;
  final OpenVirtualMicDownload _openVirtualMicDownload;
  final ReportMicPermissionDenied _reportMicPermissionDenied;
  final Duration pollInterval;

  Timer? _poll;
  bool _checking = false;

  /// Checks readiness now. [userInitiated]: the user pressed "Check again"
  /// or came back to the app, so they may have changed the permission;
  /// a denial the engine reported earlier is forgotten and retried.
  Future<void> recheck({bool userInitiated = false}) async {
    if (_checking || isClosed) return;
    _checking = true;
    try {
      final readiness = await _checkReadiness(retryDenied: userInitiated);
      if (isClosed) return;
      emit(state.copyWith(readiness: readiness));
      _updatePolling();
    } finally {
      _checking = false;
    }
  }

  /// The app came back to the foreground (e.g. from System Settings).
  Future<void> appResumed() => recheck(userInitiated: true);

  /// macOS: installs the Mute Around microphone (administrator prompt).
  Future<void> installVirtualMic() async {
    if (state.activity != .idle) return;
    emit(state.copyWith(activity: .installing, failure: null));
    final result = await _installVirtualMic();
    if (isClosed) return;
    emit(
      state.copyWith(
        activity: .idle,
        // A cancelled prompt is the user's choice, not an error to show.
        failure: switch (result.failureOrNull) {
          UserCancelled() || null => null,
          final failure => failure,
        },
      ),
    );
    // coreaudiod takes a moment to load the plug-in; polling picks it up.
    await recheck();
  }

  /// macOS: shows the microphone permission prompt.
  Future<void> requestPermission() async {
    if (state.activity != .idle) return;
    emit(state.copyWith(activity: .requestingPermission, failure: null));
    final result = await _requestMicPermission();
    if (isClosed) return;
    emit(state.copyWith(activity: .idle, failure: result.failureOrNull));
    await recheck();
  }

  Future<void> openPrivacySettings() => _runLink(_openMicPrivacySettings.call);

  Future<void> openVirtualMicDownload() =>
      _runLink(_openVirtualMicDownload.call);

  /// The engine was refused microphone access (how Windows learns about it).
  Future<void> engineReportedPermissionDenied() async {
    _reportMicPermissionDenied();
    await recheck();
  }

  Future<void> _runLink(Future<Result<Unit>> Function() open) async {
    final result = await open();
    if (isClosed) return;
    emit(state.copyWith(failure: result.failureOrNull));
  }

  void _updatePolling() {
    _poll ??= Timer.periodic(pollInterval, (_) => unawaited(recheck()));
  }

  @override
  Future<void> close() {
    _poll?.cancel();
    return super.close();
  }
}

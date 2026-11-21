import 'dart:async';
import 'dart:ffi';

import 'package:mute_around/core/native/avfoundation.ffigen.dart';
import 'package:objective_c/objective_c.dart' as objc;

/// macOS microphone authorization (TCC), as reported by `AVCaptureDevice`.
enum MacosMicAuthorization { notDetermined, restricted, denied, authorized }

/// Queries and requests macOS microphone permission from Dart through
/// ffigen's Objective-C interop: no hand-written native
/// code. macOS only; never call it on Windows.
final class MacosPermissions {
  MacosPermissions._();

  /// The shared instance; AVFoundation is loaded on first use.
  static final MacosPermissions instance = MacosPermissions._();

  late final objc.NSString _mediaTypeAudio = _loadMediaTypeAudio();

  /// The current authorization; never shows a prompt.
  MacosMicAuthorization status() => _map(
    AVCaptureDeviceAuthorization.authorizationStatusForMediaType(
      _mediaTypeAudio,
    ),
  );

  /// Shows the system prompt if the user hasn't decided yet and completes
  /// with the resulting authorization. Later calls don't prompt again.
  Future<MacosMicAuthorization> request() {
    final done = Completer<MacosMicAuthorization>();
    // The handler runs on an arbitrary dispatch queue; a listener block
    // forwards the call to this isolate.
    // AVFoundation copies the block and keeps it alive until it has run.
    final handler = ObjCBlock_ffiVoid_bool.listener((granted) {
      done.complete(granted ? .authorized : status());
    });
    AVCaptureDeviceAuthorization.requestAccessForMediaType(
      _mediaTypeAudio,
      completionHandler: handler,
    );
    return done.future;
  }

  static MacosMicAuthorization _map(AVAuthorizationStatus status) =>
      switch (status) {
        .AVAuthorizationStatusNotDetermined => .notDetermined,
        .AVAuthorizationStatusRestricted => .restricted,
        .AVAuthorizationStatusDenied => .denied,
        .AVAuthorizationStatusAuthorized => .authorized,
      };

  /// Loads AVFoundation (the Flutter runner doesn't link it) and reads the
  /// `AVMediaTypeAudio` constant from it.
  static objc.NSString _loadMediaTypeAudio() {
    final lib = DynamicLibrary.open(
      '/System/Library/Frameworks/AVFoundation.framework/AVFoundation',
    );
    final symbol = lib.lookup<Pointer<objc.ObjCObjectImpl>>(
      'AVMediaTypeAudio',
    );
    return objc.NSString.fromPointer(symbol.value, retain: true, release: true);
  }
}

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// Makes engines created from now on use miniaudio's null backend (virtual
/// devices, no hardware), via the documented `MUTE_ENGINE_BACKEND=null` hook.
void useNullAudioBackend() {
  using((arena) {
    final name = 'MUTE_ENGINE_BACKEND'.toNativeUtf8(allocator: arena);
    final value = 'null'.toNativeUtf8(allocator: arena);
    if (Platform.isWindows) {
      final putenv = DynamicLibrary.open('ucrtbase.dll')
          .lookupFunction<
            Int32 Function(Pointer<Utf8>, Pointer<Utf8>),
            int Function(Pointer<Utf8>, Pointer<Utf8>)
          >('_putenv_s');
      putenv(name, value);
    } else {
      final setenv = DynamicLibrary.process()
          .lookupFunction<
            Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Int32),
            int Function(Pointer<Utf8>, Pointer<Utf8>, int)
          >('setenv');
      setenv(name, value, 1);
    }
  });
}

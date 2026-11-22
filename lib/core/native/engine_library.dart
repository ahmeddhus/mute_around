import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:mute_around/core/failures.dart';
import 'package:mute_around/core/native/mute_engine.ffigen.dart';
import 'package:mute_around/core/result.dart';

/// ABI major version this Dart code was generated against.
const int engineAbiMajor = ME_ABI_VERSION_MAJOR;

/// Checks that the loaded native engine speaks the ABI these bindings were
/// generated for. A different major version means the layouts or semantics
/// changed, so nothing else may be called.
Result<Unit> checkEngineAbi({int Function() abiVersion = me_abi_version}) {
  try {
    final version = abiVersion();
    final major = version >> 16;
    if (major != engineAbiMajor) {
      return Err(
        EngineStateFailure(
          'Native engine ABI $major.${version & 0xffff} does not match '
          'the app (expects $engineAbiMajor.x). Rebuild the app.',
        ),
      );
    }
    return const Ok(unit);
  } on ArgumentError catch (e) {
    // The native asset couldn't be found or loaded.
    return Err(EngineStateFailure('Could not load the native engine: $e'));
  }
}

/// Finalizer that destroys an engine handle if its Dart owner is collected
/// without being disposed. A safety net only; owners call
/// `me_engine_destroy` explicitly and then detach.
final NativeFinalizer engineFinalizer = NativeFinalizer(
  Native.addressOf<NativeFunction<Void Function(Pointer<me_engine>)>>(
    me_engine_destroy,
  ).cast(),
);

/// Reads a NUL-terminated UTF-8 C string from a fixed-size char array.
String readCString(Array<Char> chars, int capacity) {
  final bytes = <int>[];
  for (var i = 0; i < capacity; i++) {
    final c = chars[i];
    if (c == 0) break;
    bytes.add(c & 0xff);
  }
  return const Utf8Decoder().convert(bytes);
}

/// Copies [value] into native memory as a C string from [arena].
Pointer<Char> toCString(String value, Arena arena) =>
    value.toNativeUtf8(allocator: arena).cast();

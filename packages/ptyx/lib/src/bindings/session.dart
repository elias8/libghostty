import 'dart:convert';
import 'dart:ffi';
import 'dart:io' show ProcessSignal;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';

import '../api/api.dart';
import '../ffi/ptyx.g.dart' as native;
import 'conversions.dart';
import 'status.dart';

const _largeWriteThreshold = 16 * 1024;

@internal
void sessionAckOutput(int sessionHandle, int byteCount) {
  checkStatus(native.ptyx_ack_output(.fromAddress(sessionHandle), byteCount));
}

@internal
void sessionFree(int sessionHandle) {
  native.ptyx_close(.fromAddress(sessionHandle));
}

@internal
bool sessionKill(int sessionHandle, ProcessSignal signal) {
  return native.ptyx_kill(.fromAddress(sessionHandle), signal.signalNumber);
}

@internal
PtyTermMode? sessionMode(int sessionHandle) {
  return using((arena) {
    final out = arena<native.term_mode>();
    final status = native.ptyx_get_term_mode(.fromAddress(sessionHandle), out);
    if (isUnsupportedStatus(status)) return null;
    checkStatus(status);
    return termModeFromNative(out.ref);
  });
}

@internal
int? sessionPid(int sessionHandle) {
  return using((arena) {
    final out = arena<Uint64>();
    final status = native.ptyx_get_child_pid(.fromAddress(sessionHandle), out);
    if (isUnsupportedStatus(status)) return null;
    checkStatus(status);
    return out.value;
  });
}

@internal
void sessionResize(int sessionHandle, PtySize size) {
  using((arena) {
    final nativeSize = native.ptyx_size.$allocate(
      arena,
      rows: size.rows,
      columns: size.columns,
      pixel_width: size.pixelWidth,
      pixel_height: size.pixelHeight,
    );
    checkStatus(
      native.ptyx_resize(.fromAddress(sessionHandle), nativeSize.ref),
    );
  });
}

@internal
PtySize sessionSize(int sessionHandle) {
  return using((arena) {
    final out = arena<native.size>();
    checkStatus(native.ptyx_get_size(.fromAddress(sessionHandle), out));
    return sizeFromNative(out.ref);
  });
}

@internal
int sessionSpawn({
  required PtySpawnOptions options,
  required int outputPort,
  required int eventPort,
}) {
  return _withNativeSessionOptions(options, (nativeOptions, sessionOut) {
    nativeOptions.ref.output_port = outputPort;
    nativeOptions.ref.event_port = eventPort;

    checkStatus(native.ptyx_spawn(nativeOptions, sessionOut));
    return sessionOut.value.address;
  });
}

@internal
String? sessionTtyName(int sessionHandle) {
  return using((arena) {
    final len = arena<Size>();
    var status = native.ptyx_get_tty_name(
      .fromAddress(sessionHandle),
      nullptr,
      len,
    );
    if (isUnsupportedStatus(status)) return null;
    if (status != native.PTYX_STATUS_BUFFER_TOO_SMALL) {
      checkStatus(status);
    }

    final buffer = arena<Char>(len.value);
    status = native.ptyx_get_tty_name(.fromAddress(sessionHandle), buffer, len);
    checkStatus(status);
    return buffer.cast<Utf8>().toDartString(length: len.value - 1);
  });
}

@internal
void sessionWrite(int sessionHandle, Uint8List data) {
  if (data.isEmpty) return;
  if (data.length >= _largeWriteThreshold) {
    _sessionWriteOwned(sessionHandle, data);
    return;
  }
  using((arena) {
    final dataPtr = arena<Uint8>(data.length);
    dataPtr.asTypedList(data.length).setAll(0, data);
    checkStatus(
      native.ptyx_write(.fromAddress(sessionHandle), dataPtr, data.length),
    );
  });
}

_NativeStringArray _nativeStringArray(Arena arena, Iterable<String> values) {
  final strings = values.toList(growable: false);
  if (strings.isEmpty) return (pointer: nullptr, length: 0);

  final pointer = arena<native.string>(strings.length);
  for (var i = 0; i < strings.length; i++) {
    _setNativeString(pointer[i], strings[i], arena);
  }
  return (pointer: pointer, length: strings.length);
}

void _sessionWriteOwned(int sessionHandle, Uint8List data) {
  using((arena) {
    final out = arena<Pointer<native.owned_buffer>>();
    checkStatus(native.ptyx_buffer_alloc(data.length, out));
    final buffer = out.value;
    try {
      final dataPtr = native.ptyx_buffer_data(buffer);
      if (dataPtr == nullptr) {
        throw const PtyException('native write buffer allocation failed');
      }
      dataPtr.asTypedList(data.length).setAll(0, data);
      checkStatus(
        native.ptyx_write_owned(
          .fromAddress(sessionHandle),
          buffer,
          data.length,
        ),
      );
    } catch (_) {
      native.ptyx_buffer_free(buffer);
      rethrow;
    }
  });
}

void _setNativeString(native.string target, String value, Arena arena) {
  if (value.isEmpty) {
    target.data = nullptr;
    target.len = 0;
    return;
  }

  final bytes = utf8.encode(value);
  final pointer = arena<Uint8>(bytes.length + 1);
  final nativeBytes = pointer.asTypedList(bytes.length + 1);
  nativeBytes.setRange(0, bytes.length, bytes);
  nativeBytes[bytes.length] = 0;
  target.data = pointer.cast<Char>();
  target.len = bytes.length;
}

T _withNativeSessionOptions<T>(
  PtySpawnOptions options,
  T Function(
    Pointer<native.session_options> pointer,
    Pointer<Pointer<native.session>> out,
  )
  run,
) {
  return using((arena) {
    final pointer = arena<native.session_options>();
    final sessionOut = arena<Pointer<native.session>>();
    final arguments = _nativeStringArray(arena, options.arguments);
    final environment = _nativeStringArray(
      arena,
      options.environment.entries.map((entry) => '${entry.key}=${entry.value}'),
    );

    native.ptyx_session_options_init(pointer);
    final ref = pointer.ref;
    _setNativeString(ref.executable, options.executable, arena);
    ref.argv = arguments.pointer;
    ref.argc = arguments.length;
    ref.env_items = environment.pointer;
    ref.env_count = environment.length;
    ref.env_mode$1 = options.environmentMode.nativeValue;
    _setNativeString(ref.cwd, options.workingDirectory ?? '', arena);
    setNativeSize(ref.initial_size, options.initialSize);
    return run(pointer, sessionOut);
  });
}

typedef _NativeStringArray = ({Pointer<native.string> pointer, int length});

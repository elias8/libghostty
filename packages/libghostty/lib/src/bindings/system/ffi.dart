import 'dart:async';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import '../../generated/libghostty.g.dart';
import '../../types/types.dart';
import '../result_helpers.dart';
import 'sys.dart';

void _writeNativeStderr(
  Pointer<Void> userdata,
  int level,
  Pointer<Uint8> scope,
  int scopeLen,
  Pointer<Uint8> message,
  int messageLen,
) {
  ghostty_sys_log_stderr(
    userdata,
    .fromValue(level),
    scope,
    scopeLen,
    message,
    messageLen,
  );
}

final class FfiSystemBindings implements SystemBindings {
  // sys.h does not expose a quiescence operation for process-global callbacks.
  // Keep the transport trampolines alive for the binding lifetime so a native
  // thread already inside a callback can never call a closed function pointer.
  NativeCallable? _sysLogTransport;
  NativeCallable? _sysStderrCallable;
  NativeCallable? _sysDecodePngCallable;
  NativeCallable? _sysRandomSecureCallable;
  SysLogCallback? _sysLogCallback;
  PngDecoder? _pngDecoder;
  SysRandomSecureCallback? _sysRandomSecure;
  Zone? _sysLogZone;

  FfiSystemBindings();

  @override
  void sysClearLogCallback() {
    final result = ghostty_sys_set(.log, nullptr);
    checkResultCode(result.value, operation: 'ghostty_sys_set(log)');
    _sysLogCallback = null;
    _sysLogZone = null;
  }

  @override
  void sysClearPngDecoder() {
    final result = ghostty_sys_set(.decodePng, nullptr);
    checkResultCode(result.value, operation: 'ghostty_sys_set(decodePng)');
    _pngDecoder = null;
  }

  @override
  void sysClearRandomSecure() {
    final result = ghostty_sys_set(.randomSecure, nullptr);
    checkResultCode(result.value, operation: 'ghostty_sys_set(randomSecure)');
    _sysRandomSecure = null;
  }

  @override
  void sysSetLogCallback(SysLogCallback callback) {
    _ensureLogTransport();
    final previousCallback = _sysLogCallback;
    final previousZone = _sysLogZone;
    _sysLogCallback = callback;
    _sysLogZone = Zone.current;
    try {
      final result = ghostty_sys_set(
        .log,
        _sysLogTransport!.nativeFunction.cast(),
      );
      checkResultCode(result.value, operation: 'ghostty_sys_set(log)');
    } on Object {
      _sysLogCallback = previousCallback;
      _sysLogZone = previousZone;
      rethrow;
    }
  }

  @override
  void sysSetLogToStderr() {
    final callable = _sysStderrCallable ??=
        NativeCallable<SysLogFnFunction>.isolateGroupBound(_writeNativeStderr);
    final result = ghostty_sys_set(.log, callable.nativeFunction.cast());
    checkResultCode(result.value, operation: 'ghostty_sys_set(log)');
    _sysLogCallback = null;
    _sysLogZone = null;
  }

  @override
  void sysSetPngDecoder(PngDecoder decoder) {
    final previous = _pngDecoder;
    _pngDecoder = decoder;
    final callable = _sysDecodePngCallable ??= _createPngCallable();
    try {
      final result = ghostty_sys_set(
        .decodePng,
        callable.nativeFunction.cast(),
      );
      checkResultCode(result.value, operation: 'ghostty_sys_set(decodePng)');
    } on Object {
      _pngDecoder = previous;
      rethrow;
    }
  }

  @override
  void sysSetRandomSecure(SysRandomSecureCallback callback) {
    _sysRandomSecure = callback;
    final callable = _sysRandomSecureCallable ??=
        NativeCallable<SysRandomSecureFnFunction>.isolateLocal((
          ffi.Pointer<ffi.Void> _,
          ffi.Pointer<ffi.Uint8> buffer,
          int length,
        ) {
          try {
            final callback = _sysRandomSecure;
            return callback != null && callback(buffer.asTypedList(length));
          } on Object {
            return false;
          }
        }, exceptionalReturn: false);
    try {
      final result = ghostty_sys_set(
        .randomSecure,
        callable.nativeFunction.cast(),
      );
      checkResultCode(result.value, operation: 'ghostty_sys_set(randomSecure)');
    } on Object {
      _sysRandomSecure = null;
      rethrow;
    }
  }

  NativeCallable _createPngCallable() {
    return NativeCallable<SysDecodePngFnFunction>.isolateLocal((
      Pointer<Void> userdata,
      Pointer<Allocator> allocator,
      Pointer<Uint8> pngData,
      int pngLen,
      Pointer<SysImage> out,
    ) {
      Pointer<Uint8> buffer = nullptr;
      var bufferLength = 0;
      try {
        final decoder = _pngDecoder;
        if (decoder == null) return false;
        final decoded = decoder(
          Uint8List.fromList(pngData.asTypedList(pngLen)),
        );
        if (decoded == null) return false;
        final rgba = decoded.rgba;
        bufferLength = rgba.length;
        buffer = ghostty_alloc(allocator, bufferLength);
        if (buffer == nullptr) return false;
        buffer.asTypedList(bufferLength).setAll(0, rgba);
        out.ref
          ..width = decoded.width
          ..height = decoded.height
          ..data = buffer
          ..data_len = bufferLength;
        buffer = nullptr;
        return true;
      } on Object {
        if (buffer != nullptr) {
          ghostty_free(allocator, buffer, bufferLength);
        }
        return false;
      }
    }, exceptionalReturn: false);
  }

  void _deliverLog(Object? message) {
    if (message is! List<Object?> || message.length != 3) return;
    final callback = _sysLogCallback;
    final zone = _sysLogZone;
    if (callback == null || zone == null) return;
    final level = message[0];
    final scope = message[1];
    final text = message[2];
    if (level is! int || scope is! Uint8List || text is! Uint8List) return;
    zone.runGuarded(() {
      callback(
        .fromValue(level),
        utf8.decode(scope, allowMalformed: true),
        utf8.decode(text, allowMalformed: true),
      );
    });
  }

  void _ensureLogTransport() {
    if (_sysLogTransport != null) return;
    final port = ReceivePort();
    port.listen(_deliverLog);
    final sendPort = port.sendPort;
    _sysLogTransport = NativeCallable<SysLogFnFunction>.isolateGroupBound((
      Pointer<Void> userdata,
      int level,
      Pointer<Uint8> scope,
      int scopeLen,
      Pointer<Uint8> message,
      int messageLen,
    ) {
      try {
        sendPort.send(<Object?>[
          level,
          Uint8List.fromList(scope.asTypedList(scopeLen)),
          Uint8List.fromList(message.asTypedList(messageLen)),
        ]);
      } on Object {
        // The native callback cannot report a Dart dispatch failure.
      }
    });
  }
}

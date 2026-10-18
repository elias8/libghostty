import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../../generated/libghostty_enums.g.dart';
import '../../generated/libghostty_wasm.g.dart';
import '../../types/types.dart';
import '../wasm/adapter.dart';
import '../wasm/layouts.dart';
import '../wasm/memory.dart';
import 'sys.dart';

final class WasmSystemBindings implements SystemBindings {
  final Memory _memory;
  final Layouts _layout;
  final web.Table _table;
  final GhosttyExports _exports;
  final _freeTableIndices = <int>[];
  int? _sysLogIndex;
  int? _sysDecodePngIndex;
  int? _sysRandomSecureIndex;

  WasmSystemBindings(this._exports, this._layout)
    : _memory = Memory(_exports),
      _table =
          (_exports['__indirect_function_table'] as web.Table?) ??
          (throw StateError(
            'WASM module does not export __indirect_function_table',
          ));

  @override
  void sysClearLogCallback() {
    _exports.ghostty_sys_set(SysOption.log.value, 0);
    if (_sysLogIndex case final index?) {
      _releaseTableIndex(index);
      _sysLogIndex = null;
    }
  }

  @override
  void sysClearPngDecoder() {
    _exports.ghostty_sys_set(SysOption.decodePng.value, 0);
    if (_sysDecodePngIndex case final index?) {
      _releaseTableIndex(index);
      _sysDecodePngIndex = null;
    }
  }

  @override
  void sysClearRandomSecure() {
    _exports.ghostty_sys_set(SysOption.randomSecure.value, 0);
    if (_sysRandomSecureIndex case final index?) {
      _releaseTableIndex(index);
      _sysRandomSecureIndex = null;
    }
  }

  @override
  void sysSetLogCallback(SysLogCallback callback) {
    _installSysLog((userdata, level, scope, scopeLen, message, messageLen) {
      try {
        callback(
          SysLogLevel.fromValue(level),
          utf8.decode(_memory.readBytes(scope, scopeLen), allowMalformed: true),
          utf8.decode(
            _memory.readBytes(message, messageLen),
            allowMalformed: true,
          ),
        );
      } on Object catch (_) {}
    });
  }

  @override
  void sysSetLogToStderr() => _installSysLog(_sysLogStderr);

  @override
  void sysSetPngDecoder(PngDecoder decoder) {
    int trampoline(
      int userdata,
      int allocator,
      int pngData,
      int pngLen,
      int out,
    ) {
      try {
        final bytes = Uint8List.fromList(_memory.readBytes(pngData, pngLen));
        final decoded = decoder(bytes);
        if (decoded == null) return 0;
        final rgba = decoded.rgba;
        final buffer = _exports.ghostty_alloc(allocator, rgba.length);
        if (buffer == 0) return 0;
        _memory.writeBytes(buffer, rgba);
        _memory.writeU32(out + _layout.sysImageWidth, decoded.width);
        _memory.writeU32(out + _layout.sysImageHeight, decoded.height);
        _memory.writePtr(out + _layout.sysImageData, buffer);
        _memory.writeU32(out + _layout.sysImageDataLen, rgba.length);
        return 1;
      } on Object catch (_) {
        return 0;
      }
    }

    final index = _registerCallback(
      trampoline.toJS,
      ['i32', 'i32', 'i32', 'i32', 'i32'],
      results: ['i32'],
      reuseIndex: _sysDecodePngIndex,
    );
    _sysDecodePngIndex = index;
    _exports.ghostty_sys_set(SysOption.decodePng.value, index);
  }

  @override
  void sysSetRandomSecure(SysRandomSecureCallback callback) {
    final index = _registerCallback(
      ((int _, int buffer, int length) {
        try {
          final bytes = Uint8List(length);
          if (!callback(bytes)) return 0;
          _memory.writeBytes(buffer, bytes);
          return 1;
        } on Object {
          return 0;
        }
      }).toJS,
      ['i32', 'i32', 'i32'],
      results: ['i32'],
      reuseIndex: _sysRandomSecureIndex,
    );
    _sysRandomSecureIndex = index;
    _exports.ghostty_sys_set(SysOption.randomSecure.value, index);
  }

  void _installSysLog(void Function(int, int, int, int, int, int) callback) {
    final index = _registerCallback(callback.toJS, [
      'i32',
      'i32',
      'i32',
      'i32',
      'i32',
      'i32',
    ], reuseIndex: _sysLogIndex);
    _sysLogIndex = index;
    _exports.ghostty_sys_set(SysOption.log.value, index);
  }

  int _registerCallback(
    JSFunction jsFunction,
    List<String> params, {
    List<String> results = const [],
    int? reuseIndex,
  }) {
    final wasmFunction = wrapJsAsWasmFunction(jsFunction, params, results);
    final index =
        reuseIndex ??
        (_freeTableIndices.isEmpty
            ? _table.grow(1)
            : _freeTableIndices.removeLast());
    _table.set(index, wasmFunction);
    return index;
  }

  void _releaseTableIndex(int index) {
    _table.set(index);
    _freeTableIndices.add(index);
  }

  void _sysLogStderr(
    int userdata,
    int level,
    int scope,
    int scopeLen,
    int message,
    int messageLen,
  ) => _exports.ghostty_sys_log_stderr(
    userdata,
    level,
    scope,
    scopeLen,
    message,
    messageLen,
  );
}

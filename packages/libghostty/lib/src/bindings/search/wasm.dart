import 'dart:convert';

import '../../generated/libghostty_enums.g.dart';
import '../../generated/libghostty_wasm.g.dart';
import '../../types/types.dart';
import '../result_helpers.dart';
import '../types.dart';
import '../wasm/allocator.dart';
import '../wasm/layouts.dart';
import '../wasm/memory.dart';
import 'search.dart';

final class WasmSearchBindings implements SearchBindings {
  final Memory _memory;
  final Layouts _layout;
  final GhosttyExports _exports;

  WasmSearchBindings(this._exports, this._layout) : _memory = Memory(_exports);

  @override
  void searchFeed(LibGhosttyHandle search) {
    _check(_exports.ghostty_search_feed(search.value), 'ghostty_search_feed');
  }

  @override
  void searchFree(LibGhosttyHandle search) {
    _exports.ghostty_search_free(search.value);
  }

  @override
  List<RawSelection> searchGetMatches(
    LibGhosttyHandle search, {
    required bool viewport,
  }) {
    final buffer = _allocateBytes(_layout.selectionBufferSize);
    try {
      _memory.writePtr(buffer + _layout.selectionBufferPtr, 0);
      _memory.writeU32(buffer + _layout.selectionBufferCap, 0);
      _memory.writeU32(buffer + _layout.selectionBufferLen, 0);
      final data = viewport ? SearchData.viewportMatches : SearchData.matches;
      var result = Result.fromValue(
        _exports.ghostty_search_get(search.value, data.value, buffer),
      );
      if (result != .outOfSpace) {
        _check(result.value, 'ghostty_search_get');
        return const [];
      }
      final capacity = _memory.readU32(buffer + _layout.selectionBufferLen);
      if (capacity == 0) return const [];
      final values = _allocateBytes(capacity * _layout.selectionSize);
      try {
        for (var i = 0; i < capacity; i++) {
          _memory.writeU32(
            values + i * _layout.selectionSize,
            _layout.selectionSize,
          );
        }
        _memory.writePtr(buffer + _layout.selectionBufferPtr, values);
        _memory.writeU32(buffer + _layout.selectionBufferCap, capacity);
        _memory.writeU32(buffer + _layout.selectionBufferLen, 0);
        result = Result.fromValue(
          _exports.ghostty_search_get(search.value, data.value, buffer),
        );
        _check(result.value, 'ghostty_search_get');
        final length = _memory.readU32(buffer + _layout.selectionBufferLen);
        return [
          for (var i = 0; i < length; i++)
            _readSelection(values + i * _layout.selectionSize),
        ];
      } finally {
        _freeBytes(values, capacity * _layout.selectionSize);
      }
    } finally {
      _freeBytes(buffer, _layout.selectionBufferSize);
    }
  }

  @override
  String? searchGetNeedle(LibGhosttyHandle search) {
    final pointer = _allocateBytes(_layout.stringSize);
    try {
      final result = Result.fromValue(
        _exports.ghostty_search_get(
          search.value,
          SearchData.needle.value,
          pointer,
        ),
      );
      if (result == .noValue) return null;
      _check(result.value, 'ghostty_search_get');
      return _readString(pointer);
    } finally {
      _freeBytes(pointer, _layout.stringSize);
    }
  }

  @override
  int? searchGetSelectedIndex(LibGhosttyHandle search) {
    return _getOptionalU32(search, SearchData.selectedIndex);
  }

  @override
  RawSelection? searchGetSelectedMatch(LibGhosttyHandle search) {
    final pointer = _allocateBytes(_layout.selectionSize);
    try {
      _memory.writeU32(pointer, _layout.selectionSize);
      final result = Result.fromValue(
        _exports.ghostty_search_get(
          search.value,
          SearchData.selectedMatch.value,
          pointer,
        ),
      );
      if (result == .noValue) return null;
      _check(result.value, 'ghostty_search_get');
      return _readSelection(pointer);
    } finally {
      _freeBytes(pointer, _layout.selectionSize);
    }
  }

  @override
  SearchScroll searchGetSelectScroll(LibGhosttyHandle search) =>
      SearchScroll.fromValue(_getU32(search, SearchData.selectScroll));

  @override
  SearchStatus searchGetStatus(LibGhosttyHandle search) =>
      SearchStatus.fromValue(_getU32(search, SearchData.status));

  @override
  int searchGetTotalMatches(LibGhosttyHandle search) =>
      _getU32(search, SearchData.totalMatches);

  @override
  LibGhosttyHandle searchNew(LibGhosttyHandle terminal) {
    final out = _requirePointer(_exports.allocateOpaque());
    try {
      _check(
        _exports.ghostty_search_new(0, out, terminal.value),
        'ghostty_search_new',
      );
      return .fromAddress(_exports.ghostty_wasm_take_opaque(out));
    } finally {
      _exports.freeOpaque(out);
    }
  }

  @override
  void searchRun(LibGhosttyHandle search) =>
      _check(_exports.ghostty_search_run(search.value), 'ghostty_search_run');

  @override
  void searchSelectNext(LibGhosttyHandle search) =>
      _select(search, .selectNext);

  @override
  void searchSelectPrevious(LibGhosttyHandle search) =>
      _select(search, .selectPrev);

  @override
  void searchSetNeedle(LibGhosttyHandle search, String? needle) {
    final value = needle == null ? null : _allocateString(needle);
    try {
      _check(
        _exports.ghostty_search_set(
          search.value,
          SearchOption.needle.value,
          value?.$1 ?? 0,
        ),
        'ghostty_search_set',
      );
    } finally {
      if (value != null) {
        _freeBytes(value.$1, _layout.stringSize);
        _freeBytes(value.$2, value.$3);
      }
    }
  }

  @override
  void searchSetSelectScroll(LibGhosttyHandle search, SearchScroll? value) {
    final pointer = value == null ? 0 : _allocateBytes(4);
    try {
      if (pointer != 0) _memory.writeU32(pointer, value!.value);
      _check(
        _exports.ghostty_search_set(
          search.value,
          SearchOption.selectScroll.value,
          pointer,
        ),
        'ghostty_search_set',
      );
    } finally {
      if (pointer != 0) _freeBytes(pointer, 4);
    }
  }

  @override
  SearchStatus searchTick(LibGhosttyHandle search) {
    final status = _allocateBytes(4);
    try {
      _check(
        _exports.ghostty_search_tick(search.value, status),
        'ghostty_search_tick',
      );
      return SearchStatus.fromValue(_memory.readU32(status));
    } finally {
      _freeBytes(status, 4);
    }
  }

  int _allocateBytes(int length) =>
      _requirePointer(_exports.allocateBytes(length));

  (int, int, int) _allocateString(String value) {
    final bytes = utf8.encode(value);
    final pointer = _allocateBytes(_layout.stringSize);
    late final int data;
    try {
      data = _allocateBytes(bytes.isEmpty ? 1 : bytes.length);
    } on Object {
      _freeBytes(pointer, _layout.stringSize);
      rethrow;
    }
    final dataLength = bytes.isEmpty ? 1 : bytes.length;
    if (bytes.isNotEmpty) _memory.writeBytes(data, bytes);
    _memory.writePtr(pointer, data);
    _memory.writeU32(pointer + _layout.stringLen, bytes.length);
    return (pointer, data, dataLength);
  }

  void _check(int code, String operation) =>
      checkResultCode(code, operation: operation);

  void _freeBytes(int pointer, int length) =>
      _exports.freeBytes(pointer, length);

  int? _getOptionalU32(LibGhosttyHandle search, SearchData data) {
    final pointer = _allocateBytes(4);
    try {
      final result = Result.fromValue(
        _exports.ghostty_search_get(search.value, data.value, pointer),
      );
      if (result == .noValue) return null;
      _check(result.value, 'ghostty_search_get');
      return _memory.readU32(pointer);
    } finally {
      _freeBytes(pointer, 4);
    }
  }

  int _getU32(LibGhosttyHandle search, SearchData data) {
    final pointer = _allocateBytes(4);
    try {
      _check(
        _exports.ghostty_search_get(search.value, data.value, pointer),
        'ghostty_search_get',
      );
      return _memory.readU32(pointer);
    } finally {
      _freeBytes(pointer, 4);
    }
  }

  RawGridRef _readGridRef(int pointer) => (
    node: _memory.readPtr(pointer + _layout.gridRefNode),
    x: _memory.readU16(pointer + _layout.gridRefX),
    y: _memory.readU16(pointer + _layout.gridRefY),
  );

  RawSelection _readSelection(int pointer) {
    return (
      start: _readGridRef(pointer + _layout.selectionStart),
      end: _readGridRef(pointer + _layout.selectionEnd),
      rectangle: _memory.readU8(pointer + _layout.selectionRectangle) != 0,
    );
  }

  String _readString(int pointer) {
    final data = _memory.readPtr(pointer);
    final length = _memory.readU32(pointer + _layout.stringLen);
    return data == 0 || length == 0
        ? ''
        : utf8.decode(_memory.readBytes(data, length));
  }

  int _requirePointer(int pointer) {
    if (pointer == 0) throw const OutOfMemoryException();
    return pointer;
  }

  void _select(LibGhosttyHandle search, SearchOption option) {
    final result = Result.fromValue(
      _exports.ghostty_search_set(search.value, option.value, 0),
    );
    if (result == .noValue) return;
    _check(result.value, 'ghostty_search_set');
  }
}

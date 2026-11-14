import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../../generated/libghostty.g.dart' as native;
import '../../generated/libghostty_enums.g.dart';
import '../result_helpers.dart';
import '../types.dart';
import 'search.dart';

final class FfiSearchBindings implements SearchBindings {
  const FfiSearchBindings();

  @override
  void searchFeed(LibGhosttyHandle search) {
    checkResultCode(
      native.ghostty_search_feed(.fromAddress(search.value)).value,
      operation: 'ghostty_search_feed',
    );
  }

  @override
  void searchFree(LibGhosttyHandle search) {
    native.ghostty_search_free(.fromAddress(search.value));
  }

  @override
  List<RawSelection> searchGetMatches(
    LibGhosttyHandle search, {
    required bool viewport,
  }) {
    return using((arena) {
      final buffer = arena<native.SelectionBuffer>();
      buffer.ref
        ..ptr = nullptr
        ..cap = 0
        ..len = 0;
      final data = viewport ? SearchData.viewportMatches : SearchData.matches;
      var result = native.ghostty_search_get(
        .fromAddress(search.value),
        data,
        buffer.cast(),
      );
      if (result != .outOfSpace) {
        checkResultCode(result.value, operation: 'ghostty_search_get');
        return const <RawSelection>[];
      }
      final capacity = buffer.ref.len;
      if (capacity == 0) return const <RawSelection>[];
      final values = arena<native.Selection>(capacity);
      buffer.ref
        ..ptr = values
        ..cap = capacity
        ..len = 0;
      result = native.ghostty_search_get(
        .fromAddress(search.value),
        data,
        buffer.cast(),
      );
      checkResultCode(result.value, operation: 'ghostty_search_get');
      return [
        for (var i = 0; i < buffer.ref.len; i++) _readSelection(values[i]),
      ];
    });
  }

  @override
  String? searchGetNeedle(LibGhosttyHandle search) {
    return using((arena) {
      final out = arena<native.String>();
      final result = native.ghostty_search_get(
        .fromAddress(search.value),
        .needle,
        out.cast(),
      );
      if (result == .noValue) return null;
      checkResultCode(result.value, operation: 'ghostty_search_get');
      return _readString(out.ref);
    });
  }

  @override
  int? searchGetSelectedIndex(LibGhosttyHandle search) {
    return using((arena) {
      final out = arena<Size>();
      final result = native.ghostty_search_get(
        .fromAddress(search.value),
        .selectedIndex,
        out.cast(),
      );
      if (result == .noValue) return null;
      checkResultCode(result.value, operation: 'ghostty_search_get');
      return out.value;
    });
  }

  @override
  RawSelection? searchGetSelectedMatch(LibGhosttyHandle search) {
    return using((arena) {
      final out = arena<native.Selection>();
      final result = native.ghostty_search_get(
        .fromAddress(search.value),
        .selectedMatch,
        out.cast(),
      );
      if (result == .noValue) return null;
      checkResultCode(result.value, operation: 'ghostty_search_get');
      return _readSelection(out.ref);
    });
  }

  @override
  SearchScroll searchGetSelectScroll(LibGhosttyHandle search) {
    return using((arena) {
      final out = arena<UnsignedInt>();
      final result = native.ghostty_search_get(
        .fromAddress(search.value),
        .selectScroll,
        out.cast(),
      );
      checkResultCode(result.value, operation: 'ghostty_search_get');
      return SearchScroll.fromValue(out.value);
    });
  }

  @override
  SearchStatus searchGetStatus(LibGhosttyHandle search) {
    return using((arena) {
      final out = arena<UnsignedInt>();
      final result = native.ghostty_search_get(
        .fromAddress(search.value),
        .status,
        out.cast(),
      );
      checkResultCode(result.value, operation: 'ghostty_search_get');
      return SearchStatus.fromValue(out.value);
    });
  }

  @override
  int searchGetTotalMatches(LibGhosttyHandle search) {
    return using((arena) {
      final out = arena<Size>();
      final result = native.ghostty_search_get(
        .fromAddress(search.value),
        .totalMatches,
        out.cast(),
      );
      checkResultCode(result.value, operation: 'ghostty_search_get');
      return out.value;
    });
  }

  @override
  LibGhosttyHandle searchNew(LibGhosttyHandle terminal) {
    return using((arena) {
      final out = arena<Pointer<native.SearchImpl>>();
      final result = native.ghostty_search_new(
        nullptr,
        out,
        .fromAddress(terminal.value),
      );
      checkResultCode(result.value, operation: 'ghostty_search_new');
      return .fromAddress(out.value.address);
    });
  }

  @override
  void searchRun(LibGhosttyHandle search) {
    checkResultCode(
      native.ghostty_search_run(.fromAddress(search.value)).value,
      operation: 'ghostty_search_run',
    );
  }

  @override
  void searchSelectNext(LibGhosttyHandle search) {
    final result = native.ghostty_search_select_next(
      .fromAddress(search.value),
    );
    if (result != .noValue) {
      checkResultCode(result.value, operation: 'ghostty_search_select_next');
    }
  }

  @override
  void searchSelectPrevious(LibGhosttyHandle search) {
    final result = native.ghostty_search_select_prev(
      .fromAddress(search.value),
    );
    if (result != .noValue) {
      checkResultCode(result.value, operation: 'ghostty_search_select_prev');
    }
  }

  @override
  void searchSetNeedle(LibGhosttyHandle search, String? needle) {
    using((arena) {
      final result = native.ghostty_search_set(
        .fromAddress(search.value),
        .needle,
        needle == null ? nullptr.cast() : _allocateString(arena, needle),
      );
      checkResultCode(result.value, operation: 'ghostty_search_set');
    });
  }

  @override
  void searchSetSelectScroll(LibGhosttyHandle search, SearchScroll? value) {
    using((arena) {
      final pointer = value == null
          ? nullptr.cast<UnsignedInt>()
          : (arena<UnsignedInt>()..value = value.value);
      final result = native.ghostty_search_set(
        .fromAddress(search.value),
        .selectScroll,
        pointer.cast(),
      );
      checkResultCode(result.value, operation: 'ghostty_search_set');
    });
  }

  @override
  SearchStatus searchTick(LibGhosttyHandle search) {
    return using((arena) {
      final out = arena<UnsignedInt>();
      final result = native.ghostty_search_tick(
        .fromAddress(search.value),
        out,
      );
      checkResultCode(result.value, operation: 'ghostty_search_tick');
      return SearchStatus.fromValue(out.value);
    });
  }

  static Pointer<Void> _allocateString(Arena arena, String value) {
    final bytes = utf8.encode(value);
    final data = arena<Uint8>(bytes.isEmpty ? 1 : bytes.length);
    if (bytes.isNotEmpty) data.asTypedList(bytes.length).setAll(0, bytes);
    return native.String.$allocate(arena, ptr: data, len: bytes.length).cast();
  }

  static RawGridRef _readGridRef(native.GridRef value) {
    return (node: value.node.address, x: value.x, y: value.y);
  }

  static RawSelection _readSelection(native.Selection value) => (
    start: _readGridRef(value.start),
    end: _readGridRef(value.end),
    rectangle: value.rectangle,
  );

  static String _readString(native.String value) {
    if (value.ptr == nullptr || value.len == 0) return '';
    return utf8.decode(value.ptr.asTypedList(value.len));
  }
}

import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../../generated/libghostty.g.dart' hide String;
import '../../generated/libghostty_enums.g.dart';
import '../../types/types.dart';
import '../result_helpers.dart';
import '../types.dart';
import 'formatter.dart';

final class FfiFormatterBindings implements FormatterBindings {
  var _formatBuffer = calloc<Uint8>(4096);
  var _formatBufferCapacity = 4096;
  final _written = calloc<Size>();

  FfiFormatterBindings();

  @override
  String formatterFormat(LibGhosttyHandle formatter) {
    var result = ghostty_formatter_format_buf(
      Pointer.fromAddress(formatter.value),
      _formatBuffer,
      _formatBufferCapacity,
      _written,
    );
    if (result == .outOfSpace) {
      _growFormatBuffer(_written.value);
      result = ghostty_formatter_format_buf(
        Pointer.fromAddress(formatter.value),
        _formatBuffer,
        _formatBufferCapacity,
        _written,
      );
    }
    checkResultCode(result.value, operation: 'ghostty_formatter_format_buf');
    final length = _written.value;
    return length == 0 ? '' : utf8.decode(_formatBuffer.asTypedList(length));
  }

  @override
  void formatterFree(LibGhosttyHandle formatter) {
    ghostty_formatter_free(Pointer.fromAddress(formatter.value));
  }

  @override
  void formatterSetSelection(
    LibGhosttyHandle formatter,
    RawSelection? selection,
  ) {
    using((arena) {
      final selected = selection == null ? nullptr : arena<Selection>();
      if (selection != null) _writeSelection(selected.ref, selection);
      checkResultCode(
        ghostty_formatter_set(
          Pointer.fromAddress(formatter.value),
          .selection,
          selected.cast(),
        ).value,
        operation: 'ghostty_formatter_set',
      );
    });
  }

  @override
  LibGhosttyHandle formatterTerminalNew(
    LibGhosttyHandle terminal,
    FormatterFormat format, {
    bool unwrap = false,
    bool trim = false,
    FormatterExtra extra = const FormatterExtra(),
    RawSelection? selection,
  }) {
    return using((arena) {
      final out = arena<Pointer<FormatterImpl>>();
      final result = ghostty_formatter_terminal_new(
        nullptr,
        out,
        Pointer.fromAddress(terminal.value),
      );
      checkResultCode(
        result.value,
        operation: 'ghostty_formatter_terminal_new',
      );
      final formatter = out.value;
      try {
        void set(FormatterOption option, Pointer<Void> value) {
          checkResultCode(
            ghostty_formatter_set(formatter, option, value).value,
            operation: 'ghostty_formatter_set',
          );
        }

        final scalar = arena<Uint32>()..value = format.value;
        set(.emit, scalar.cast());
        final flag = arena<Bool>()..value = unwrap;
        set(.unwrap, flag.cast());
        flag.value = trim;
        set(.trim, flag.cast());
        scalar.value = formatterExtrasMask(extra);
        set(.extras, scalar.cast());
        if (selection != null) {
          final selected = arena<Selection>();
          _writeSelection(selected.ref, selection);
          set(.selection, selected.cast());
        }
        return .fromAddress(formatter.address);
      } on Object {
        ghostty_formatter_free(formatter);
        rethrow;
      }
    });
  }

  void _growFormatBuffer(int required) {
    if (required <= _formatBufferCapacity) return;
    final replacement = calloc<Uint8>(required);
    calloc.free(_formatBuffer);
    _formatBuffer = replacement;
    _formatBufferCapacity = required;
  }

  static void _writeGridRef(GridRef target, RawGridRef value) {
    target
      ..node = Pointer<Void>.fromAddress(value.node)
      ..x = value.x
      ..y = value.y;
  }

  static void _writeSelection(Selection target, RawSelection selection) {
    target.rectangle = selection.rectangle;
    _writeGridRef(target.start, selection.start);
    _writeGridRef(target.end, selection.end);
  }
}

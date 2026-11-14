import 'dart:convert';
import 'dart:typed_data';

import '../../generated/libghostty_enums.g.dart';
import '../../generated/libghostty_wasm.g.dart';
import '../../types/types.dart';
import '../result_helpers.dart';
import '../types.dart';
import '../wasm/allocator.dart';
import '../wasm/layouts.dart';
import '../wasm/memory.dart';
import '../wasm/scratch.dart';
import 'utility.dart';

final class WasmUtilityBindings implements UtilityBindings {
  final Memory _memory;
  final Layouts _layout;
  final GhosttyExports _exports;
  final WasmScratchPool _scratch;

  WasmUtilityBindings(this._exports, this._layout)
    : _memory = Memory(_exports),
      _scratch = WasmScratchPool(
        WasmExportScratchAllocator(_exports),
        maxVariableLength: WasmScratchPool.defaultMaxVariableLength,
      );

  @override
  int buildInfo(BuildInfo data) {
    final frame = _scratch.acquire(const []);
    try {
      final output = frame.variableAddress(
        0,
        wasm32PointerSize,
        alignment: wasm32PointerSize,
      );
      final result = _exports.ghostty_build_info(data.value, output);
      checkResultCode(result, operation: 'ghostty_build_info');
      return _memory.readU32(output);
    } finally {
      frame.release();
    }
  }

  @override
  bool buildInfoBool(BuildInfo data) {
    final frame = _scratch.acquire(const []);
    try {
      final output = frame.variableAddress(0, 1);
      final result = _exports.ghostty_build_info(data.value, output);
      checkResultCode(result, operation: 'ghostty_build_info');
      return _memory.readU8(output) != 0;
    } finally {
      frame.release();
    }
  }

  @override
  String buildInfoString(BuildInfo data) {
    final frame = _scratch.acquire(const []);
    try {
      final output = frame.variableAddress(0, _layout.stringSize);
      final result = _exports.ghostty_build_info(data.value, output);
      checkResultCode(result, operation: 'ghostty_build_info');
      final pointer = _memory.readPtr(output);
      final length = _memory.readU32(output + _layout.stringLen);
      if (pointer == 0 || length == 0) return '';
      return utf8.decode(_memory.readBytes(pointer, length));
    } finally {
      frame.release();
    }
  }

  @override
  double colorContrast(RgbColor a, RgbColor b) {
    final frame = _scratch.acquire(const []);
    try {
      final aPointer = frame.variableAddress(0, _layout.colorRgbSize);
      final bPointer = frame.variableAddress(1, _layout.colorRgbSize);
      _writeRgb(aPointer, a);
      _writeRgb(bPointer, b);
      return _exports.ghostty_color_contrast(aPointer, bPointer);
    } finally {
      frame.release();
    }
  }

  @override
  double colorLuminance(RgbColor color) {
    final frame = _scratch.acquire(const []);
    try {
      final pointer = frame.variableAddress(0, _layout.colorRgbSize);
      _writeRgb(pointer, color);
      return _exports.ghostty_color_luminance(pointer);
    } finally {
      frame.release();
    }
  }

  @override
  List<RgbColor> colorPaletteDefault() {
    final bytes = 256 * _layout.colorRgbSize;
    final frame = _scratch.acquire(const []);
    try {
      final output = frame.variableAddress(0, bytes);
      _exports.ghostty_color_palette_default(output);
      return _readPalette(output);
    } finally {
      frame.release();
    }
  }

  @override
  List<RgbColor> colorPaletteGenerate({
    List<RgbColor>? base,
    Set<int> skip = const {},
    required RgbColor background,
    required RgbColor foreground,
    required bool harmonious,
  }) {
    final paletteBytes = 256 * _layout.colorRgbSize;
    const skipBytes = 32;
    final frame = _scratch.acquire(const []);
    try {
      final basePointer = base == null
          ? 0
          : frame.variableAddress(0, paletteBytes);
      final skipPointer = skip.isEmpty
          ? 0
          : frame.variableAddress(1, skipBytes);
      final backgroundPointer = frame.variableAddress(2, _layout.colorRgbSize);
      final foregroundPointer = frame.variableAddress(3, _layout.colorRgbSize);
      final output = frame.variableAddress(4, paletteBytes);
      _writeRgb(backgroundPointer, background);
      _writeRgb(foregroundPointer, foreground);
      if (base != null) {
        for (var i = 0; i < 256; i++) {
          _writeRgb(basePointer + i * _layout.colorRgbSize, base[i]);
        }
      }
      if (skip.isNotEmpty) {
        for (var i = 0; i < skipBytes; i++) {
          _memory.writeU8(skipPointer + i, 0);
        }
        for (final index in skip) {
          final address = skipPointer + (index >> 3);
          final bit = 1 << (index & 7);
          _memory.writeU8(address, _memory.readU8(address) | bit);
        }
      }
      _exports.ghostty_color_palette_generate(
        basePointer,
        skipPointer,
        backgroundPointer,
        foregroundPointer,
        harmonious ? 1 : 0,
        output,
      );
      return _readPalette(output);
    } finally {
      frame.release();
    }
  }

  @override
  RgbColor colorParse(String value) {
    final input = _allocUtf8(value);
    final frame = _scratch.acquire(const []);
    try {
      final output = frame.variableAddress(0, _layout.colorRgbSize);
      final result = _exports.ghostty_color_parse(
        input.pointer,
        input.length,
        output,
      );
      checkResultCode(result, operation: 'ghostty_color_parse');
      return _readRgb(output);
    } finally {
      frame.release();
      _freeUtf8(input);
    }
  }

  @override
  ({int index, RgbColor color}) colorParsePaletteEntry(String value) {
    final input = _allocUtf8(value);
    final frame = _scratch.acquire(const []);
    try {
      final index = frame.variableAddress(0, 1);
      final color = frame.variableAddress(1, _layout.colorRgbSize);
      final result = _exports.ghostty_color_parse_palette_entry(
        input.pointer,
        input.length,
        index,
        color,
      );
      checkResultCode(result, operation: 'ghostty_color_parse_palette_entry');
      return (index: _memory.readU8(index), color: _readRgb(color));
    } finally {
      frame.release();
      _freeUtf8(input);
    }
  }

  @override
  RgbColor colorParseX11(String name) {
    final input = _allocUtf8(name);
    final frame = _scratch.acquire(const []);
    try {
      final output = frame.variableAddress(0, _layout.colorRgbSize);
      final result = _exports.ghostty_color_parse_x11(
        input.pointer,
        input.length,
        output,
      );
      checkResultCode(result, operation: 'ghostty_color_parse_x11');
      return _readRgb(output);
    } finally {
      frame.release();
      _freeUtf8(input);
    }
  }

  @override
  double colorPerceivedLuminance(RgbColor color) {
    final frame = _scratch.acquire(const []);
    try {
      final pointer = frame.variableAddress(0, _layout.colorRgbSize);
      _writeRgb(pointer, color);
      return _exports.ghostty_color_perceived_luminance(pointer);
    } finally {
      frame.release();
    }
  }

  @override
  String colorSchemeReportEncode(ColorScheme scheme) {
    final frame = _scratch.acquire(const []);
    var buffer = 0;
    var capacity = 0;
    try {
      final written = frame.variableAddress(
        0,
        wasm32PointerSize,
        alignment: wasm32PointerSize,
      );
      var result = _exports.ghostty_color_scheme_report_encode(
        scheme.value,
        0,
        0,
        written,
      );
      if (result != Result.outOfSpace.value) {
        checkResultCode(
          result,
          operation: 'ghostty_color_scheme_report_encode',
        );
        return '';
      }
      capacity = _memory.readU32(written);
      buffer = frame.variableAddress(1, capacity == 0 ? 1 : capacity);
      result = _exports.ghostty_color_scheme_report_encode(
        scheme.value,
        buffer,
        capacity,
        written,
      );
      checkResultCode(result, operation: 'ghostty_color_scheme_report_encode');
      return utf8.decode(_memory.readBytes(buffer, _memory.readU32(written)));
    } finally {
      frame.release();
    }
  }

  @override
  List<X11ColorName> colorX11Names() {
    final names = _exports.ghostty_color_x11_names();
    final count = _exports.ghostty_color_x11_name_count();
    return [
      for (var i = 0; i < count; i++)
        X11ColorName(
          name: _memory.readCString(
            _memory.readPtr(
              names + i * _layout.colorX11EntrySize + _layout.colorX11EntryName,
            ),
          ),
          color: _readRgb(
            names + i * _layout.colorX11EntrySize + _layout.colorX11EntryColor,
          ),
        ),
    ];
  }

  @override
  String focusEncode(FocusEvent event) {
    final frame = _scratch.acquire(const []);
    const capacity = 8;
    try {
      final written = frame.variableAddress(
        0,
        wasm32PointerSize,
        alignment: wasm32PointerSize,
      );
      final output = frame.variableAddress(1, capacity);
      final result = _exports.ghostty_focus_encode(
        event.value,
        output,
        capacity,
        written,
      );
      checkResultCode(result, operation: 'ghostty_focus_encode');
      return utf8.decode(_memory.readBytes(output, _memory.readU32(written)));
    } finally {
      frame.release();
    }
  }

  @override
  String modeReportEncode(int mode, ModeReportState state) {
    final frame = _scratch.acquire(const []);
    const capacity = 64;
    try {
      final written = frame.variableAddress(
        0,
        wasm32PointerSize,
        alignment: wasm32PointerSize,
      );
      final output = frame.variableAddress(1, capacity);
      final result = _exports.ghostty_mode_report_encode(
        mode,
        state.value,
        output,
        capacity,
        written,
      );
      checkResultCode(result, operation: 'ghostty_mode_report_encode');
      return utf8.decode(_memory.readBytes(output, _memory.readU32(written)));
    } finally {
      frame.release();
    }
  }

  @override
  Uint8List pasteEncode(String data, {required bool bracketed}) {
    final input = _allocUtf8(data);
    final frame = _scratch.acquire(const []);
    var output = 0;
    var capacity = 0;
    try {
      final written = frame.variableAddress(
        0,
        wasm32PointerSize,
        alignment: wasm32PointerSize,
      );
      var result = _exports.ghostty_paste_encode(
        input.pointer,
        input.length,
        bracketed ? 1 : 0,
        0,
        0,
        written,
      );
      if (result != Result.outOfSpace.value) {
        checkResultCode(result, operation: 'ghostty_paste_encode');
        return Uint8List(0);
      }
      capacity = _memory.readU32(written);
      output = frame.variableAddress(1, capacity == 0 ? 1 : capacity);
      result = _exports.ghostty_paste_encode(
        input.pointer,
        input.length,
        bracketed ? 1 : 0,
        output,
        capacity,
        written,
      );
      checkResultCode(result, operation: 'ghostty_paste_encode');
      return Uint8List.fromList(
        _memory.readBytes(output, _memory.readU32(written)),
      );
    } finally {
      _freeUtf8(input);
      frame.release();
    }
  }

  @override
  bool pasteIsSafe(String data) {
    final encoded = utf8.encode(data);
    if (encoded.isEmpty) return _exports.ghostty_paste_is_safe(0, 0) != 0;
    final frame = _scratch.acquire(const []);
    try {
      final pointer = frame.variableAddress(0, encoded.length);
      _memory.writeBytes(pointer, encoded);
      return _exports.ghostty_paste_is_safe(pointer, encoded.length) != 0;
    } finally {
      frame.release();
    }
  }

  @override
  String sizeReportEncode(
    SizeReportStyle style,
    int rows,
    int columns,
    int cellWidth,
    int cellHeight,
  ) {
    final frame = _scratch.acquire(const []);
    const capacity = 64;
    try {
      final size = frame.variableAddress(0, _layout.sizeReportSize);
      final written = frame.variableAddress(
        1,
        wasm32PointerSize,
        alignment: wasm32PointerSize,
      );
      final output = frame.variableAddress(2, capacity);
      _memory.writeU16(size, rows);
      _memory.writeU16(size + _layout.sizeReportColumns, columns);
      _memory.writeU32(size + _layout.sizeReportCellWidth, cellWidth);
      _memory.writeU32(size + _layout.sizeReportCellHeight, cellHeight);
      final result = _exports.ghostty_size_report_encode(
        style.value,
        size,
        output,
        capacity,
        written,
      );
      checkResultCode(result, operation: 'ghostty_size_report_encode');
      return utf8.decode(_memory.readBytes(output, _memory.readU32(written)));
    } finally {
      frame.release();
    }
  }

  @override
  Style styleDefault() {
    final frame = _scratch.acquire(const []);
    try {
      final pointer = frame.variableAddress(0, 16);
      _exports.ghostty_style_default(pointer);
      return _readStyle(pointer);
    } finally {
      frame.release();
    }
  }

  @override
  bool styleIsDefault(Style style) {
    final frame = _scratch.acquire(const []);
    try {
      final pointer = frame.variableAddress(0, 16);
      _writeStyle(pointer, style);
      return _exports.ghostty_style_is_default(pointer) != 0;
    } finally {
      frame.release();
    }
  }

  @override
  int unicodeCodepointWidth(int codepoint) =>
      _exports.ghostty_unicode_codepoint_width(codepoint);

  @override
  ({int consumed, int width}) unicodeGraphemeWidth(List<int> codepoints) {
    final bytes = codepoints.isEmpty ? 0 : codepoints.length * 4;
    final frame = _scratch.acquire(const []);
    try {
      final pointer = bytes == 0 ? 0 : frame.variableAddress(0, bytes);
      final width = frame.variableAddress(1, 1);
      for (var i = 0; i < codepoints.length; i++) {
        _memory.writeU32(pointer + i * 4, codepoints[i]);
      }
      final consumed = _exports.ghostty_unicode_grapheme_width(
        pointer,
        codepoints.length,
        width,
      );
      return (consumed: consumed, width: _memory.readU8(width));
    } finally {
      frame.release();
    }
  }

  @override
  String version() => _memory.readCString(_exports.ghostty_version());

  ({int pointer, int length, int allocation}) _allocUtf8(String value) {
    final bytes = utf8.encode(value);
    final allocation = bytes.isEmpty ? 1 : bytes.length;
    final pointer = _requirePointer(_exports.allocateBytes(allocation));
    _memory.writeBytes(pointer, bytes);
    return (pointer: pointer, length: bytes.length, allocation: allocation);
  }

  void _freeUtf8(({int pointer, int length, int allocation}) value) {
    _exports.freeBytes(value.pointer, value.allocation);
  }

  List<RgbColor> _readPalette(int pointer) => [
    for (var i = 0; i < 256; i++) _readRgb(pointer + i * _layout.colorRgbSize),
  ];

  RawColor _readRawColor(int address) => (
    tag: StyleColorTag.fromValue(_memory.readU8(address)),
    palette: _memory.readU8(address + 1),
    r: _memory.readU8(address + 1),
    g: _memory.readU8(address + 2),
    b: _memory.readU8(address + 3),
  );

  RgbColor _readRgb(int pointer) => RgbColor(
    _memory.readU8(pointer + _layout.colorRgbR),
    _memory.readU8(pointer + _layout.colorRgbG),
    _memory.readU8(pointer + _layout.colorRgbB),
  );

  Style _readStyle(int pointer) {
    final underline = _readRawColor(pointer + 8);
    return Style(
      foreground: cellColorFromRaw(_readRawColor(pointer)),
      background: cellColorFromRaw(_readRawColor(pointer + 4)),
      underlineColor: switch (underline.tag) {
        .rgb || .palette => cellColorFromRaw(underline),
        .none => null,
      },
      bold: _memory.readU16(pointer + 12) & (1 << 0) != 0,
      italic: _memory.readU16(pointer + 12) & (1 << 1) != 0,
      faint: _memory.readU16(pointer + 12) & (1 << 2) != 0,
      blink: _memory.readU16(pointer + 12) & (1 << 3) != 0,
      inverse: _memory.readU16(pointer + 12) & (1 << 4) != 0,
      invisible: _memory.readU16(pointer + 12) & (1 << 5) != 0,
      strikethrough: _memory.readU16(pointer + 12) & (1 << 6) != 0,
      overline: _memory.readU16(pointer + 12) & (1 << 7) != 0,
      underline: .fromValue((_memory.readU16(pointer + 12) >> 8) & 7),
    );
  }

  int _requirePointer(int pointer) {
    if (pointer == 0) throw const OutOfMemoryException();
    return pointer;
  }

  void _writeRgb(int pointer, RgbColor color) {
    _memory.writeU8(pointer + _layout.colorRgbR, color.r);
    _memory.writeU8(pointer + _layout.colorRgbG, color.g);
    _memory.writeU8(pointer + _layout.colorRgbB, color.b);
  }

  void _writeStyle(int pointer, Style style) {
    _writeStyleColor(pointer, style.foreground);
    _writeStyleColor(pointer + 4, style.background);
    _writeStyleColor(pointer + 8, style.underlineColor);
    _memory.writeU16(pointer + 12, styleFlags(style));
    _memory.writeU16(pointer + 14, 0);
  }

  void _writeStyleColor(int address, CellColor? color) {
    switch (color) {
      case RgbColor(:final r, :final g, :final b):
        _memory.writeU8(address, StyleColorTag.rgb.value);
        _memory.writeU8(address + 1, r);
        _memory.writeU8(address + 2, g);
        _memory.writeU8(address + 3, b);
      case PaletteColor(:final index):
        _memory.writeU8(address, StyleColorTag.palette.value);
        _memory.writeU8(address + 1, index);
        _memory.writeU8(address + 2, 0);
        _memory.writeU8(address + 3, 0);
      case DefaultColor() || null:
        _memory.writeU8(address, StyleColorTag.none.value);
        _memory.writeU8(address + 1, 0);
        _memory.writeU8(address + 2, 0);
        _memory.writeU8(address + 3, 0);
    }
  }
}

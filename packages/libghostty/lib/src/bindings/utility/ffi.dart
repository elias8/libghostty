import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../../generated/libghostty.g.dart' as native;
import '../../generated/libghostty_enums.g.dart';
import '../../types/types.dart';
import '../result_helpers.dart';
import '../types.dart';
import 'utility.dart';

final class FfiUtilityBindings implements UtilityBindings {
  const FfiUtilityBindings();

  @override
  int buildInfo(BuildInfo data) {
    return using((arena) {
      final output = arena<Size>();
      final result = native.ghostty_build_info(data, output.cast());
      checkResultCode(result.value, operation: 'ghostty_build_info');
      return output.value;
    });
  }

  @override
  bool buildInfoBool(BuildInfo data) {
    return using((arena) {
      final output = arena<Bool>();
      final result = native.ghostty_build_info(data, output.cast());
      checkResultCode(result.value, operation: 'ghostty_build_info');
      return output.value;
    });
  }

  @override
  String buildInfoString(BuildInfo data) {
    return using((arena) {
      final output = arena<native.String>();
      final result = native.ghostty_build_info(data, output.cast());
      checkResultCode(result.value, operation: 'ghostty_build_info');
      if (output.ref.ptr == nullptr || output.ref.len == 0) return '';
      return utf8.decode(output.ref.ptr.asTypedList(output.ref.len));
    });
  }

  @override
  double colorContrast(RgbColor a, RgbColor b) {
    return using((arena) {
      final aPointer = native.ColorRgb.$allocate(arena, r: a.r, g: a.g, b: a.b);
      final bPointer = native.ColorRgb.$allocate(arena, r: b.r, g: b.g, b: b.b);
      return native.ghostty_color_contrast(aPointer, bPointer);
    });
  }

  @override
  double colorLuminance(RgbColor color) {
    return using((arena) {
      final pointer = native.ColorRgb.$allocate(
        arena,
        r: color.r,
        g: color.g,
        b: color.b,
      );
      return native.ghostty_color_luminance(pointer);
    });
  }

  @override
  List<RgbColor> colorPaletteDefault() {
    return using((arena) {
      final output = arena<native.ColorRgb>(256);
      native.ghostty_color_palette_default(output);
      return _readPalette(output);
    });
  }

  @override
  List<RgbColor> colorPaletteGenerate({
    List<RgbColor>? base,
    Set<int> skip = const {},
    required RgbColor background,
    required RgbColor foreground,
    required bool harmonious,
  }) {
    return using((arena) {
      final basePointer = base == null ? nullptr : arena<native.ColorRgb>(256);
      if (base != null) {
        for (var i = 0; i < 256; i++) {
          _writeRgb(basePointer[i], base[i]);
        }
      }
      final skipPointer = skip.isEmpty
          ? nullptr
          : arena<native.ColorPaletteMask>();
      if (skip.isNotEmpty) {
        for (var i = 0; i < 4; i++) {
          skipPointer.ref.bits[i] = 0;
        }
        for (final index in skip) {
          skipPointer.ref.bits[index >> 6] |= 1 << (index & 63);
        }
      }
      final backgroundPointer = native.ColorRgb.$allocate(
        arena,
        r: background.r,
        g: background.g,
        b: background.b,
      );
      final foregroundPointer = native.ColorRgb.$allocate(
        arena,
        r: foreground.r,
        g: foreground.g,
        b: foreground.b,
      );
      final output = arena<native.ColorRgb>(256);
      native.ghostty_color_palette_generate(
        basePointer,
        skipPointer,
        backgroundPointer,
        foregroundPointer,
        harmonious,
        output,
      );
      return _readPalette(output);
    });
  }

  @override
  RgbColor colorParse(String value) {
    return using((arena) {
      final encoded = utf8.encode(value);
      final pointer = arena<Char>(encoded.isEmpty ? 1 : encoded.length);
      pointer.cast<Uint8>().asTypedList(encoded.length).setAll(0, encoded);
      final output = arena<native.ColorRgb>();
      final result = native.ghostty_color_parse(
        pointer,
        encoded.length,
        output,
      );
      checkResultCode(result.value, operation: 'ghostty_color_parse');
      return RgbColor(output.ref.r, output.ref.g, output.ref.b);
    });
  }

  @override
  ({int index, RgbColor color}) colorParsePaletteEntry(String value) {
    return using((arena) {
      final encoded = utf8.encode(value);
      final pointer = arena<Char>(encoded.isEmpty ? 1 : encoded.length);
      pointer.cast<Uint8>().asTypedList(encoded.length).setAll(0, encoded);
      final index = arena<Uint8>();
      final color = arena<native.ColorRgb>();
      final result = native.ghostty_color_parse_palette_entry(
        pointer,
        encoded.length,
        index,
        color,
      );
      checkResultCode(
        result.value,
        operation: 'ghostty_color_parse_palette_entry',
      );
      return (
        index: index.value,
        color: RgbColor(color.ref.r, color.ref.g, color.ref.b),
      );
    });
  }

  @override
  RgbColor colorParseX11(String name) {
    return using((arena) {
      final encoded = utf8.encode(name);
      final pointer = arena<Char>(encoded.isEmpty ? 1 : encoded.length);
      pointer.cast<Uint8>().asTypedList(encoded.length).setAll(0, encoded);
      final output = arena<native.ColorRgb>();
      final result = native.ghostty_color_parse_x11(
        pointer,
        encoded.length,
        output,
      );
      checkResultCode(result.value, operation: 'ghostty_color_parse_x11');
      return RgbColor(output.ref.r, output.ref.g, output.ref.b);
    });
  }

  @override
  double colorPerceivedLuminance(RgbColor color) {
    return using((arena) {
      final pointer = native.ColorRgb.$allocate(
        arena,
        r: color.r,
        g: color.g,
        b: color.b,
      );
      return native.ghostty_color_perceived_luminance(pointer);
    });
  }

  @override
  String colorSchemeReportEncode(ColorScheme scheme) {
    return using((arena) {
      final written = arena<Size>();
      var result = native.ghostty_color_scheme_report_encode(
        scheme,
        nullptr,
        0,
        written,
      );
      if (result != .outOfSpace) {
        checkResultCode(
          result.value,
          operation: 'ghostty_color_scheme_report_encode',
        );
        return '';
      }
      final buffer = arena<Uint8>(written.value);
      result = native.ghostty_color_scheme_report_encode(
        scheme,
        buffer,
        written.value,
        written,
      );
      checkResultCode(
        result.value,
        operation: 'ghostty_color_scheme_report_encode',
      );
      return utf8.decode(buffer.cast<Uint8>().asTypedList(written.value));
    });
  }

  @override
  List<X11ColorName> colorX11Names() {
    final names = native.ghostty_color_x11_names();
    final count = native.ghostty_color_x11_name_count();
    return [
      for (var i = 0; i < count; i++)
        X11ColorName(
          name: names[i].name.cast<Utf8>().toDartString(),
          color: RgbColor(names[i].color.r, names[i].color.g, names[i].color.b),
        ),
    ];
  }

  @override
  String focusEncode(FocusEvent event) {
    return using((arena) {
      final written = arena<Size>();
      final output = arena<Uint8>(8);
      final result = native.ghostty_focus_encode(event, output, 8, written);
      checkResultCode(result.value, operation: 'ghostty_focus_encode');
      return utf8.decode(output.cast<Uint8>().asTypedList(written.value));
    });
  }

  @override
  String modeReportEncode(int mode, ModeReportState state) {
    return using((arena) {
      final written = arena<Size>();
      final output = arena<Uint8>(64);
      final result = native.ghostty_mode_report_encode(
        mode,
        state,
        output,
        64,
        written,
      );
      checkResultCode(result.value, operation: 'ghostty_mode_report_encode');
      return utf8.decode(output.cast<Uint8>().asTypedList(written.value));
    });
  }

  @override
  Uint8List pasteEncode(String data, {required bool bracketed}) {
    return using((arena) {
      final encoded = utf8.encode(data);
      final input = arena<Char>(encoded.isEmpty ? 1 : encoded.length);
      input.cast<Uint8>().asTypedList(encoded.length).setAll(0, encoded);
      final written = arena<Size>();
      var result = native.ghostty_paste_encode(
        input,
        encoded.length,
        bracketed,
        nullptr,
        0,
        written,
      );
      if (result != .outOfSpace) {
        checkResultCode(result.value, operation: 'ghostty_paste_encode');
        return Uint8List(0);
      }
      final output = arena<Uint8>(written.value);
      input.cast<Uint8>().asTypedList(encoded.length).setAll(0, encoded);
      result = native.ghostty_paste_encode(
        input,
        encoded.length,
        bracketed,
        output,
        written.value,
        written,
      );
      checkResultCode(result.value, operation: 'ghostty_paste_encode');
      return Uint8List.fromList(
        output.cast<Uint8>().asTypedList(written.value),
      );
    });
  }

  @override
  bool pasteIsSafe(String data) {
    return using((arena) {
      final encoded = utf8.encode(data);
      final pointer = arena<Char>(encoded.isEmpty ? 1 : encoded.length);
      pointer.cast<Uint8>().asTypedList(encoded.length).setAll(0, encoded);
      return native.ghostty_paste_is_safe(pointer, encoded.length);
    });
  }

  @override
  String sizeReportEncode(
    SizeReportStyle style,
    int rows,
    int columns,
    int cellWidth,
    int cellHeight,
  ) {
    return using((arena) {
      final written = arena<Size>();
      final output = arena<Uint8>(64);
      final size = native.SizeReportSize.$allocate(
        arena,
        rows: rows,
        columns: columns,
        cell_width: cellWidth,
        cell_height: cellHeight,
      );
      final result = native.ghostty_size_report_encode(
        style,
        size,
        output,
        64,
        written,
      );
      checkResultCode(result.value, operation: 'ghostty_size_report_encode');
      return utf8.decode(output.cast<Uint8>().asTypedList(written.value));
    });
  }

  @override
  Style styleDefault() {
    return using((arena) {
      final style = arena<native.Style>();
      native.ghostty_style_default(style);
      return _readStyle(style.ref);
    });
  }

  @override
  bool styleIsDefault(Style style) {
    return using((arena) {
      final nativeStyle = arena<native.Style>();
      _writeColor(nativeStyle.ref.fg_color, _toRaw(style.foreground));
      _writeColor(nativeStyle.ref.bg_color, _toRaw(style.background));
      _writeColor(
        nativeStyle.ref.underline_color,
        style.underlineColor == null
            ? defaultRawColor
            : _toRaw(style.underlineColor!),
      );
      nativeStyle.ref.flags = styleFlags(style);
      nativeStyle.ref.reserved = 0;
      return native.ghostty_style_is_default(nativeStyle);
    });
  }

  @override
  int unicodeCodepointWidth(int codepoint) =>
      native.ghostty_unicode_codepoint_width(codepoint);

  @override
  ({int consumed, int width}) unicodeGraphemeWidth(List<int> codepoints) {
    return using((arena) {
      final pointer = codepoints.isEmpty
          ? nullptr
          : arena<Uint32>(codepoints.length);
      for (var i = 0; i < codepoints.length; i++) {
        pointer[i] = codepoints[i];
      }
      final width = arena<Uint8>();
      final consumed = native.ghostty_unicode_grapheme_width(
        pointer,
        codepoints.length,
        width,
      );
      return (consumed: consumed, width: width.value);
    });
  }

  @override
  String version() => native.ghostty_version().cast<Utf8>().toDartString();

  static RawColor _readColor(native.StyleColor color) => (
    tag: StyleColorTag.fromValue(color.tag),
    palette: color.value.palette,
    r: color.value.rgb.r,
    g: color.value.rgb.g,
    b: color.value.rgb.b,
  );

  static List<RgbColor> _readPalette(Pointer<native.ColorRgb> pointer) => [
    for (var i = 0; i < 256; i++)
      RgbColor(pointer[i].r, pointer[i].g, pointer[i].b),
  ];

  static Style _readStyle(native.Style style) {
    final underline = _readColor(style.underline_color);
    return Style(
      foreground: cellColorFromRaw(_readColor(style.fg_color)),
      background: cellColorFromRaw(_readColor(style.bg_color)),
      underlineColor: switch (underline.tag) {
        .rgb || .palette => cellColorFromRaw(underline),
        .none => null,
      },
      bold: style.flags & (1 << 0) != 0,
      italic: style.flags & (1 << 1) != 0,
      faint: style.flags & (1 << 2) != 0,
      blink: style.flags & (1 << 3) != 0,
      inverse: style.flags & (1 << 4) != 0,
      invisible: style.flags & (1 << 5) != 0,
      strikethrough: style.flags & (1 << 6) != 0,
      overline: style.flags & (1 << 7) != 0,
      underline: .fromValue((style.flags >> 8) & 7),
    );
  }

  static RawColor _toRaw(CellColor color) => switch (color) {
    DefaultColor() => defaultRawColor,
    PaletteColor(:final index) => (
      tag: StyleColorTag.palette,
      palette: index,
      r: 0,
      g: 0,
      b: 0,
    ),
    RgbColor(:final r, :final g, :final b) => (
      tag: StyleColorTag.rgb,
      palette: 0,
      r: r,
      g: g,
      b: b,
    ),
  };

  static void _writeColor(native.StyleColor target, RawColor color) {
    target.tag = color.tag.value;
    target.value.rgb.r = color.tag == .palette ? color.palette : color.r;
    target.value.rgb.g = color.g;
    target.value.rgb.b = color.b;
  }

  static void _writeRgb(native.ColorRgb target, RgbColor color) {
    target
      ..r = color.r
      ..g = color.g
      ..b = color.b;
  }
}

import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../../generated/libghostty.g.dart' as native;
import '../../generated/libghostty_enums.g.dart';
import '../../types/types.dart';
import '../result_helpers.dart';
import '../types.dart';
import 'parser.dart';

final class FfiParserBindings implements ParserBindings {
  const FfiParserBindings();

  @override
  OscCommandType oscCommandType(LibGhosttyHandle command) {
    return native.ghostty_osc_command_type(
      native.OscCommand.fromAddress(command.value),
    );
  }

  @override
  String? oscCommandWindowTitle(LibGhosttyHandle command) {
    return using((arena) {
      final out = arena<Pointer<Char>>();
      final present = native.ghostty_osc_command_data(
        native.OscCommand.fromAddress(command.value),
        OscCommandData.changeWindowTitleStr,
        out.cast(),
      );
      if (!present || out.value == nullptr) return null;
      return out.value.cast<Utf8>().toDartString();
    });
  }

  @override
  RawOscUnknownCommandData? oscCommandUnknownData(LibGhosttyHandle command) {
    return using((arena) {
      final nativeCommand = native.OscCommand.fromAddress(command.value);
      final content = arena<native.String>();
      if (!native.ghostty_osc_command_data(
        nativeCommand,
        OscCommandData.unknownContent,
        content.cast(),
      )) {
        return null;
      }
      final truncated = arena<Bool>();
      final hasTruncated = native.ghostty_osc_command_data(
        nativeCommand,
        OscCommandData.unknownTruncated,
        truncated.cast(),
      );
      final terminator = arena<Uint32>();
      final hasTerminator = native.ghostty_osc_command_data(
        nativeCommand,
        OscCommandData.unknownTerminator,
        terminator.cast(),
      );
      if (!hasTruncated || !hasTerminator) return null;
      return (
        content: Uint8List.fromList(
          content.ref.ptr.asTypedList(content.ref.len),
        ),
        truncated: truncated.value,
        terminator: OscTerminator.fromValue(terminator.value),
      );
    });
  }

  @override
  LibGhosttyHandle oscEnd(LibGhosttyHandle parser, int terminator) {
    final command = native.ghostty_osc_end(
      Pointer.fromAddress(parser.value),
      terminator,
    );
    return .fromAddress(command.address);
  }

  @override
  void oscFeedByte(LibGhosttyHandle parser, int byte) {
    native.ghostty_osc_next(Pointer.fromAddress(parser.value), byte);
  }

  @override
  void oscFree(LibGhosttyHandle parser) {
    native.ghostty_osc_free(Pointer.fromAddress(parser.value));
  }

  @override
  LibGhosttyHandle oscNew({required int unknownMaxBytes}) {
    return using((arena) {
      final out = arena<Pointer<native.OscParserImpl>>();
      final result = native.ghostty_osc_new(nullptr, out);
      checkResultCode(result.value, operation: 'ghostty_osc_new');
      final handle = LibGhosttyHandle.fromAddress(out.value.address);
      if (unknownMaxBytes == 0) return handle;
      try {
        final value = arena<Size>()..value = unknownMaxBytes;
        checkResultCode(
          native
              .ghostty_osc_set(
                out.value,
                OscOption.unknownMaxBytes,
                value.cast(),
              )
              .value,
          operation: 'ghostty_osc_set',
        );
      } on Object {
        native.ghostty_osc_free(out.value);
        rethrow;
      }
      return handle;
    });
  }

  @override
  void oscReset(LibGhosttyHandle parser) {
    native.ghostty_osc_reset(Pointer.fromAddress(parser.value));
  }

  @override
  void sgrFree(LibGhosttyHandle parser) {
    native.ghostty_sgr_free(Pointer.fromAddress(parser.value));
  }

  @override
  LibGhosttyHandle sgrNew() {
    return using((arena) {
      final out = arena<Pointer<native.SgrParserImpl>>();
      final result = native.ghostty_sgr_new(nullptr, out);
      checkResultCode(result.value, operation: 'ghostty_sgr_new');
      return .fromAddress(out.value.address);
    });
  }

  @override
  SgrAttribute? sgrNext(LibGhosttyHandle parser) {
    return using((arena) {
      final out = arena<native.SgrAttribute>();
      final present = native.ghostty_sgr_next(
        Pointer.fromAddress(parser.value),
        out,
      );
      if (!present) return null;
      return _readSgrAttribute(out.ref);
    });
  }

  @override
  void sgrReset(LibGhosttyHandle parser) {
    native.ghostty_sgr_reset(Pointer.fromAddress(parser.value));
  }

  @override
  void sgrSetParams(
    LibGhosttyHandle parser,
    List<int> params,
    List<String>? separators,
  ) {
    checkResultCode(
      using((arena) {
        final nativeParams = arena<Uint16>(params.length);
        for (var i = 0; i < params.length; i++) {
          nativeParams[i] = params[i];
        }

        Pointer<Char> nativeSeparators = nullptr;
        if (separators != null) {
          nativeSeparators = arena<Char>(separators.length);
          for (var i = 0; i < separators.length; i++) {
            (nativeSeparators + i).value = separators[i].codeUnitAt(0);
          }
        }

        return native.ghostty_sgr_set_params(
          Pointer.fromAddress(parser.value),
          nativeParams,
          nativeSeparators,
          params.length,
        );
      }).value,
      operation: 'ghostty_sgr_set_params',
    );
  }

  SgrAttribute _readSgrAttribute(native.SgrAttribute attribute) {
    final tag = SgrAttributeTag.fromValue(attribute.tagAsInt);
    final value = attribute.value;
    return switch (tag) {
      .unknown => SgrAttribute(
        tag: tag,
        unknownFull: [
          for (var i = 0; i < value.unknown.full_len; i++)
            value.unknown.full_ptr[i],
        ],
        unknownPartial: [
          for (var i = 0; i < value.unknown.partial_len; i++)
            value.unknown.partial_ptr[i],
        ],
      ),
      .underline => SgrAttribute(
        tag: tag,
        underlineStyle: .fromValue(value.underlineAsInt),
      ),
      .underlineColor => SgrAttribute(
        tag: tag,
        color: RgbColor(
          value.underline_color.r,
          value.underline_color.g,
          value.underline_color.b,
        ),
      ),
      .directColorFg => SgrAttribute(
        tag: tag,
        color: RgbColor(
          value.direct_color_fg.r,
          value.direct_color_fg.g,
          value.direct_color_fg.b,
        ),
      ),
      .directColorBg => SgrAttribute(
        tag: tag,
        color: RgbColor(
          value.direct_color_bg.r,
          value.direct_color_bg.g,
          value.direct_color_bg.b,
        ),
      ),
      .underlineColor256 => SgrAttribute(
        tag: tag,
        paletteIndex: value.underline_color_256,
      ),
      .fg8 => SgrAttribute(tag: tag, paletteIndex: value.fg_8),
      .bg8 => SgrAttribute(tag: tag, paletteIndex: value.bg_8),
      .brightFg8 => SgrAttribute(tag: tag, paletteIndex: value.bright_fg_8),
      .brightBg8 => SgrAttribute(tag: tag, paletteIndex: value.bright_bg_8),
      .fg256 => SgrAttribute(tag: tag, paletteIndex: value.fg_256),
      .bg256 => SgrAttribute(tag: tag, paletteIndex: value.bg_256),
      _ => SgrAttribute(tag: tag),
    };
  }
}

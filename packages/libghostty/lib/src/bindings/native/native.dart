import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../../ffi/libghostty.g.dart'
    as native
    show
        ClipboardWrite,
        MouseEncoderSize,
        SgrAttribute,
        String,
        Style,
        TerminalModeConfig;
import '../../ffi/libghostty.g.dart'
    hide
        ClipboardContent,
        ClipboardWrite,
        MouseEncoderSize,
        SgrAttribute,
        String,
        Style;
import '../../ffi/libghostty_enums.g.dart';
import '../interface.dart';

typedef _StringBuffer = ({Pointer<native.String> str, Pointer<Uint8> data});

// NativeCallable requires a compile-time constant exceptional return.
const _clipboardWriteExceptionResult = 5;

final GhosttyBindings bindings = NativeBindings();

Future<void> initializeForWeb(Uri wasmUri) async {}

const RawPlacement _emptyPlacement = (
  imageId: 0,
  placementId: 0,
  isVirtual: false,
  xOffset: 0,
  yOffset: 0,
  sourceX: 0,
  sourceY: 0,
  sourceWidth: 0,
  sourceHeight: 0,
  columns: 0,
  rows: 0,
  z: 0,
);

const RawPlacementRenderInfo _emptyRenderInfo = (
  pixelWidth: 0,
  pixelHeight: 0,
  gridCols: 0,
  gridRows: 0,
  viewportCol: 0,
  viewportRow: 0,
  viewportVisible: false,
  sourceX: 0,
  sourceY: 0,
  sourceWidth: 0,
  sourceHeight: 0,
);

const RawGridRef _emptyGridRef = (node: 0, x: 0, y: 0);
const TerminalGeometry _emptyTerminalGeometry = (
  cols: 0,
  rows: 0,
  widthPx: 0,
  heightPx: 0,
);
const RawRenderStateSummary _emptyRenderStateSummary = (
  cols: 0,
  rows: 0,
  dirty: .false$,
);
const RawRenderStateCursor _emptyRenderStateCursor = (
  visualStyle: .block,
  visible: false,
  blinking: false,
  passwordInput: false,
  inViewport: false,
  viewportX: 0,
  viewportY: 0,
  viewportWideTail: false,
);
const RawSelectionGestureState _emptySelectionGestureState = (
  clickCount: 0,
  dragged: false,
  autoscroll: .none,
  behavior: .cell,
  anchor: null,
);

const _rowIteratorSummaryKeys = <RenderStateRowData>[.dirty, .raw];
const _rowCellsSummaryKeys = <RenderStateRowCellsData>[
  .raw,
  .graphemesLen,
  .selected,
];
const _cellSummaryKeys = <CellData>[.codepoint, .styleId, .wide];
const _rowSummaryKeys = <RowData>[
  .wrap,
  .wrapContinuation,
  .grapheme,
  .styled,
  .hyperlink,
  .semanticPrompt,
  .kittyVirtualPlaceholder,
];
const _selectionGestureStateKeys = <SelectionGestureData>[
  .clickCount,
  .dragged,
  .autoscroll,
  .behavior,
  .anchor,
];
const _kittyImagePixelDataKeys = <KittyGraphicsImageData>[.dataPtr, .dataLen];
const _kittyPlacementKeys = <KittyGraphicsPlacementData>[
  .imageId,
  .placementId,
  .isVirtual,
  .xOffset,
  .yOffset,
  .sourceX,
  .sourceY,
  .sourceWidth,
  .sourceHeight,
  .columns,
  .rows,
  .z,
];
const _cursorStateKeys = <RenderStateData>[
  .cursorVisualStyle,
  .cursorVisible,
  .cursorBlinking,
  .cursorPasswordInput,
  .cursorViewportHasValue,
  .cursorViewportX,
  .cursorViewportY,
  .cursorViewportWideTail,
];
const _renderStateSummaryKeys = <RenderStateData>[.cols, .rows, .dirty];

class NativeBindings implements GhosttyBindings {
  final _utf8Ptrs = <int, Pointer<Char>>{};
  final _callables = <int, Map<TerminalOption, NativeCallable>>{};
  ({Object error, StackTrace stackTrace})? _callbackError;
  final _stringBuffers = <int, Map<TerminalOption, _StringBuffer>>{};

  NativeCallable? _sysLogCallable;
  NativeCallable? _sysDecodePngCallable;

  void _captureCallbackError(Object error, StackTrace stackTrace) {
    _callbackError ??= (error: error, stackTrace: stackTrace);
  }

  T _runNestedCallbackOperation<T>(T Function() operation) {
    final previousFailure = _callbackError!;
    _callbackError = null;
    late final T result;
    late final ({Object error, StackTrace stackTrace})? failure;
    try {
      result = operation();
    } finally {
      failure = _callbackError;
      _callbackError = previousFailure;
    }
    if (failure != null) {
      Error.throwWithStackTrace(failure.error, failure.stackTrace);
    }
    return result;
  }

  final _outU8 = calloc<Uint8>();
  final _outU16 = calloc<Uint16>();
  final _outU32 = calloc<Uint32>();
  final _outU64 = calloc<Uint64>();
  final _outI32 = calloc<Int32>();
  final _outBool = calloc<Bool>();
  final _outModeConfig = calloc<native.TerminalModeConfig>();
  final _outStyle = calloc<native.Style>();
  final _outScrollbar = calloc<TerminalScrollbar>();
  final _outColors = calloc<RenderStateColors>();
  final _outSize = calloc<Size>();
  final _outGhosttyString = calloc<native.String>();
  final _outColorRgb = calloc<ColorRgb>();
  final _graphemeBuf = calloc<Uint32>(32);
  final _outOpaque = calloc<Pointer<Void>>();
  final _multiKeys = calloc<UnsignedInt>(12);
  final _multiValues = calloc<Pointer<Void>>(12);
  final _multiOut = calloc<Uint64>(12);
  final _multiGridRef = calloc<GridRef>();
  final _renderStateSummaryMultiKeys = calloc<UnsignedInt>(
    _renderStateSummaryKeys.length,
  );
  final _renderStateSummaryMultiValues = calloc<Pointer<Void>>(
    _renderStateSummaryKeys.length,
  );
  final _renderStateSummaryMultiOut = calloc<Uint64>(
    _renderStateSummaryKeys.length,
  );
  final _cursorMultiKeys = calloc<UnsignedInt>(_cursorStateKeys.length);
  final _cursorMultiValues = calloc<Pointer<Void>>(_cursorStateKeys.length);
  final _cursorMultiOut = calloc<Uint64>(_cursorStateKeys.length);
  final _rowCellsMultiKeys = calloc<UnsignedInt>(_rowCellsSummaryKeys.length);
  final _rowCellsMultiValues = calloc<Pointer<Void>>(
    _rowCellsSummaryKeys.length,
  );
  final _rowCellsMultiOut = calloc<Uint64>(_rowCellsSummaryKeys.length);
  final _cellMultiKeys = calloc<UnsignedInt>(_cellSummaryKeys.length);
  final _cellMultiValues = calloc<Pointer<Void>>(_cellSummaryKeys.length);
  final _cellMultiOut = calloc<Uint64>(_cellSummaryKeys.length);
  Pointer<Uint8> _formatBuffer = calloc<Uint8>(4096);
  late int _formatBufferCapacity;

  NativeBindings() {
    _formatBufferCapacity = 4096;
    _outColors.ref.size = sizeOf<RenderStateColors>();
    _outStyle.ref.size = sizeOf<native.Style>();
    for (var i = 0; i < _renderStateSummaryKeys.length; i++) {
      _renderStateSummaryMultiKeys[i] = _renderStateSummaryKeys[i].value;
      _renderStateSummaryMultiValues[i] = (_renderStateSummaryMultiOut + i)
          .cast();
    }
    for (var i = 0; i < _cursorStateKeys.length; i++) {
      _cursorMultiKeys[i] = _cursorStateKeys[i].value;
      _cursorMultiValues[i] = (_cursorMultiOut + i).cast();
    }
    for (var i = 0; i < _rowCellsSummaryKeys.length; i++) {
      _rowCellsMultiKeys[i] = _rowCellsSummaryKeys[i].value;
      _rowCellsMultiValues[i] = (_rowCellsMultiOut + i).cast();
    }
    for (var i = 0; i < _cellSummaryKeys.length; i++) {
      _cellMultiKeys[i] = _cellSummaryKeys[i].value;
      _cellMultiValues[i] = (_cellMultiOut + i).cast();
    }
  }

  @override
  CResult<int> keyEventNew() {
    return using((arena) {
      final ptr = arena<Pointer<KeyEventImpl>>();
      final result = ghostty_key_event_new(nullptr, ptr);
      return (result, ptr.value.address);
    });
  }

  @override
  void keyEventFree(int handle) {
    _freeUtf8(handle);
    ghostty_key_event_free(Pointer.fromAddress(handle));
  }

  @override
  void keyEventSetAction(int handle, KeyAction action) {
    ghostty_key_event_set_action(Pointer.fromAddress(handle), action);
  }

  @override
  KeyAction keyEventGetAction(int handle) {
    return ghostty_key_event_get_action(Pointer.fromAddress(handle));
  }

  @override
  void keyEventSetKey(int handle, Key key) {
    ghostty_key_event_set_key(Pointer.fromAddress(handle), key);
  }

  @override
  Key keyEventGetKey(int handle) {
    return ghostty_key_event_get_key(Pointer.fromAddress(handle));
  }

  @override
  void keyEventSetMods(int handle, int mods) {
    ghostty_key_event_set_mods(Pointer.fromAddress(handle), mods);
  }

  @override
  int keyEventGetMods(int handle) {
    return ghostty_key_event_get_mods(Pointer.fromAddress(handle));
  }

  @override
  void keyEventSetConsumedMods(int handle, int mods) {
    ghostty_key_event_set_consumed_mods(Pointer.fromAddress(handle), mods);
  }

  @override
  int keyEventGetConsumedMods(int handle) {
    return ghostty_key_event_get_consumed_mods(Pointer.fromAddress(handle));
  }

  @override
  void keyEventSetComposing(int handle, {required bool composing}) {
    ghostty_key_event_set_composing(Pointer.fromAddress(handle), composing);
  }

  @override
  bool keyEventGetComposing(int handle) {
    return ghostty_key_event_get_composing(Pointer.fromAddress(handle));
  }

  @override
  void keyEventSetUtf8(int handle, String? text) {
    _freeUtf8(handle);
    final ptr = Pointer<KeyEventImpl>.fromAddress(handle);
    if (text == null) {
      ghostty_key_event_set_utf8(ptr, nullptr, 0);
      return;
    }
    final encoded = utf8.encode(text);
    final charPtr = calloc<Char>(encoded.length);
    final dst = charPtr.cast<Uint8>().asTypedList(encoded.length);
    dst.setAll(0, encoded);
    _utf8Ptrs[handle] = charPtr;
    ghostty_key_event_set_utf8(ptr, charPtr, encoded.length);
  }

  @override
  String? keyEventGetUtf8(int handle) {
    return using((arena) {
      final lenPtr = arena<Size>();
      final charPtr = ghostty_key_event_get_utf8(
        Pointer.fromAddress(handle),
        lenPtr,
      );
      if (charPtr == nullptr) return null;
      final len = lenPtr.value;
      if (len == 0) return null;
      return utf8.decode(charPtr.cast<Uint8>().asTypedList(len));
    });
  }

  @override
  void keyEventSetUnshiftedCodepoint(int handle, int codepoint) {
    ghostty_key_event_set_unshifted_codepoint(
      Pointer.fromAddress(handle),
      codepoint,
    );
  }

  @override
  int keyEventGetUnshiftedCodepoint(int handle) {
    return ghostty_key_event_get_unshifted_codepoint(
      Pointer.fromAddress(handle),
    );
  }

  @override
  CResult<int> keyEncoderNew() {
    return using((arena) {
      final ptr = arena<Pointer<KeyEncoderImpl>>();
      final result = ghostty_key_encoder_new(nullptr, ptr);
      return (result, ptr.value.address);
    });
  }

  @override
  void keyEncoderFree(int handle) {
    ghostty_key_encoder_free(Pointer.fromAddress(handle));
  }

  @override
  void keyEncoderSetBoolOpt(
    int handle,
    KeyEncoderOption option, {
    required bool value,
  }) {
    using((arena) {
      final ptr = arena<Bool>()..value = value;
      ghostty_key_encoder_setopt(
        Pointer.fromAddress(handle),
        option,
        ptr.cast(),
      );
    });
  }

  @override
  void keyEncoderSetKittyFlags(int handle, int flags) {
    using((arena) {
      final ptr = arena<Uint8>()..value = flags;
      ghostty_key_encoder_setopt(
        Pointer.fromAddress(handle),
        KeyEncoderOption.kittyFlags,
        ptr.cast(),
      );
    });
  }

  @override
  void keyEncoderSetOptionAsAlt(int handle, OptionAsAlt value) {
    using((arena) {
      final ptr = arena<Int32>()..value = value.value;
      ghostty_key_encoder_setopt(
        Pointer.fromAddress(handle),
        KeyEncoderOption.macosOptionAsAlt,
        ptr.cast(),
      );
    });
  }

  @override
  void keyEncoderSetOptFromTerminal(int encoder, int terminal) {
    ghostty_key_encoder_setopt_from_terminal(
      Pointer.fromAddress(encoder),
      Pointer.fromAddress(terminal),
    );
  }

  @override
  CResult<String> keyEncoderEncode(int encoder, int event) {
    return using((arena) {
      final outLen = arena<Size>();
      var bufSize = 128;
      var buf = arena<Char>(bufSize);
      var result = ghostty_key_encoder_encode(
        Pointer.fromAddress(encoder),
        Pointer.fromAddress(event),
        buf,
        bufSize,
        outLen,
      );

      // Retry with the required size if the initial buffer was too small.
      if (result == Result.outOfSpace) {
        bufSize = outLen.value;
        buf = arena<Char>(bufSize);
        result = ghostty_key_encoder_encode(
          Pointer.fromAddress(encoder),
          Pointer.fromAddress(event),
          buf,
          bufSize,
          outLen,
        );
      }

      final len = outLen.value;
      return (result, utf8.decode(buf.cast<Uint8>().asTypedList(len)));
    });
  }

  @override
  CResult<int> mouseEventNew() {
    return using((arena) {
      final ptr = arena<Pointer<MouseEventImpl>>();
      final result = ghostty_mouse_event_new(nullptr, ptr);
      return (result, ptr.value.address);
    });
  }

  @override
  void mouseEventFree(int handle) {
    ghostty_mouse_event_free(Pointer.fromAddress(handle));
  }

  @override
  void mouseEventSetAction(int handle, MouseAction action) {
    ghostty_mouse_event_set_action(Pointer.fromAddress(handle), action);
  }

  @override
  MouseAction mouseEventGetAction(int handle) {
    return ghostty_mouse_event_get_action(Pointer.fromAddress(handle));
  }

  @override
  void mouseEventSetButton(int handle, MouseButton button) {
    ghostty_mouse_event_set_button(Pointer.fromAddress(handle), button);
  }

  @override
  void mouseEventClearButton(int handle) {
    ghostty_mouse_event_clear_button(Pointer.fromAddress(handle));
  }

  @override
  CResult<MouseButton> mouseEventGetButton(int handle) {
    return using((arena) {
      final out = arena<Int32>();
      final hasButton = ghostty_mouse_event_get_button(
        Pointer.fromAddress(handle),
        out.cast(),
      );
      final result = hasButton ? Result.success : Result.noValue;
      return (result, MouseButton.fromValue(out.value));
    });
  }

  @override
  void mouseEventSetMods(int handle, int mods) {
    ghostty_mouse_event_set_mods(Pointer.fromAddress(handle), mods);
  }

  @override
  int mouseEventGetMods(int handle) {
    return ghostty_mouse_event_get_mods(Pointer.fromAddress(handle));
  }

  @override
  void mouseEventSetPosition(int handle, double x, double y) {
    using((arena) {
      final pos = MousePosition.$allocate(arena, x: x, y: y);
      ghostty_mouse_event_set_position(Pointer.fromAddress(handle), pos.ref);
    });
  }

  @override
  (double, double) mouseEventGetPosition(int handle) {
    final pos = ghostty_mouse_event_get_position(Pointer.fromAddress(handle));
    return (pos.x, pos.y);
  }

  @override
  CResult<int> mouseEncoderNew() {
    return using((arena) {
      final ptr = arena<Pointer<MouseEncoderImpl>>();
      final result = ghostty_mouse_encoder_new(nullptr, ptr);
      return (result, ptr.value.address);
    });
  }

  @override
  void mouseEncoderFree(int handle) {
    ghostty_mouse_encoder_free(Pointer.fromAddress(handle));
  }

  @override
  void mouseEncoderSetBoolOpt(
    int handle,
    MouseEncoderOption option, {
    required bool value,
  }) {
    using((arena) {
      final ptr = arena<Bool>()..value = value;
      ghostty_mouse_encoder_setopt(
        Pointer.fromAddress(handle),
        option,
        ptr.cast(),
      );
    });
  }

  @override
  void mouseEncoderSetTrackingMode(int handle, MouseTrackingMode mode) {
    using((arena) {
      final ptr = arena<Int32>()..value = mode.value;
      ghostty_mouse_encoder_setopt(
        Pointer.fromAddress(handle),
        MouseEncoderOption.event,
        ptr.cast(),
      );
    });
  }

  @override
  void mouseEncoderSetFormat(int handle, MouseFormat format) {
    using((arena) {
      final ptr = arena<Int32>()..value = format.value;
      ghostty_mouse_encoder_setopt(
        Pointer.fromAddress(handle),
        MouseEncoderOption.format,
        ptr.cast(),
      );
    });
  }

  @override
  void mouseEncoderSetSize(int handle, MouseEncoderSize size) {
    using((arena) {
      final ptr = native.MouseEncoderSize.$allocate(
        arena,
        size: sizeOf<native.MouseEncoderSize>(),
        screen_width: size.screenWidth,
        screen_height: size.screenHeight,
        cell_width: size.cellWidth,
        cell_height: size.cellHeight,
        padding_top: size.paddingTop,
        padding_bottom: size.paddingBottom,
        padding_left: size.paddingLeft,
        padding_right: size.paddingRight,
      );
      ghostty_mouse_encoder_setopt(
        Pointer.fromAddress(handle),
        MouseEncoderOption.size,
        ptr.cast(),
      );
    });
  }

  @override
  void mouseEncoderSetOptFromTerminal(int encoder, int terminal) {
    ghostty_mouse_encoder_setopt_from_terminal(
      Pointer.fromAddress(encoder),
      Pointer.fromAddress(terminal),
    );
  }

  @override
  void mouseEncoderReset(int handle) {
    ghostty_mouse_encoder_reset(Pointer.fromAddress(handle));
  }

  @override
  CResult<String> mouseEncoderEncode(int encoder, int event) {
    return using((arena) {
      final outLen = arena<Size>();
      var bufSize = 128;
      var buf = arena<Char>(bufSize);
      var result = ghostty_mouse_encoder_encode(
        Pointer.fromAddress(encoder),
        Pointer.fromAddress(event),
        buf,
        bufSize,
        outLen,
      );

      // Retry with the required size if the initial buffer was too small.
      if (result == Result.outOfSpace) {
        bufSize = outLen.value;
        buf = arena<Char>(bufSize);
        result = ghostty_mouse_encoder_encode(
          Pointer.fromAddress(encoder),
          Pointer.fromAddress(event),
          buf,
          bufSize,
          outLen,
        );
      }

      final len = outLen.value;
      return (result, utf8.decode(buf.cast<Uint8>().asTypedList(len)));
    });
  }

  @override
  CResult<int> oscNew() {
    return using((arena) {
      final ptr = arena<Pointer<OscParserImpl>>();
      final result = ghostty_osc_new(nullptr, ptr);
      return (result, ptr.value.address);
    });
  }

  @override
  void oscFree(int handle) {
    ghostty_osc_free(Pointer.fromAddress(handle));
  }

  @override
  void oscFeedByte(int handle, int byte) {
    ghostty_osc_next(Pointer.fromAddress(handle), byte);
  }

  @override
  int oscEnd(int handle, int terminator) {
    return ghostty_osc_end(Pointer.fromAddress(handle), terminator).address;
  }

  @override
  OscCommandType oscCommandType(int command) {
    return ghostty_osc_command_type(OscCommand.fromAddress(command));
  }

  @override
  String? oscCommandWindowTitle(int command) {
    return _extractWindowTitle(OscCommand.fromAddress(command));
  }

  @override
  void oscReset(int handle) {
    ghostty_osc_reset(Pointer.fromAddress(handle));
  }

  @override
  CResult<int> sgrNew() {
    return using((arena) {
      final ptr = arena<Pointer<SgrParserImpl>>();
      final result = ghostty_sgr_new(nullptr, ptr);
      return (result, ptr.value.address);
    });
  }

  @override
  void sgrFree(int handle) {
    ghostty_sgr_free(Pointer.fromAddress(handle));
  }

  @override
  Result sgrSetParams(int handle, List<int> params, List<String>? separators) {
    return using((arena) {
      final nativeParams = arena<Uint16>(params.length);
      for (var i = 0; i < params.length; i++) {
        nativeParams[i] = params[i];
      }

      Pointer<Char> nativeSeps = nullptr;
      if (separators != null) {
        nativeSeps = arena<Char>(separators.length);
        for (var i = 0; i < separators.length; i++) {
          (nativeSeps + i).value = separators[i].codeUnitAt(0);
        }
      }

      return ghostty_sgr_set_params(
        Pointer.fromAddress(handle),
        nativeParams,
        nativeSeps,
        params.length,
      );
    });
  }

  @override
  SgrAttribute? sgrNext(int handle) {
    return using((arena) {
      final attrPtr = arena<native.SgrAttribute>();
      final hasNext = ghostty_sgr_next(Pointer.fromAddress(handle), attrPtr);
      if (!hasNext) return null;
      return _convertNativeSgrAttribute(attrPtr.ref);
    });
  }

  @override
  void sgrReset(int handle) {
    ghostty_sgr_reset(Pointer.fromAddress(handle));
  }

  @override
  bool pasteIsSafe(String data) {
    return using((arena) {
      final encoded = utf8.encode(data);
      final ptr = arena<Char>(encoded.length);
      ptr.cast<Uint8>().asTypedList(encoded.length).setAll(0, encoded);
      return ghostty_paste_is_safe(ptr, encoded.length);
    });
  }

  @override
  double colorContrast(RgbColor a, RgbColor b) {
    return using((arena) {
      final aPtr = ColorRgb.$allocate(arena, r: a.r, g: a.g, b: a.b);
      final bPtr = ColorRgb.$allocate(arena, r: b.r, g: b.g, b: b.b);
      return ghostty_color_contrast(aPtr, bPtr);
    });
  }

  @override
  double colorLuminance(RgbColor color) {
    return using((arena) {
      final ptr = ColorRgb.$allocate(arena, r: color.r, g: color.g, b: color.b);
      return ghostty_color_luminance(ptr);
    });
  }

  @override
  double colorPerceivedLuminance(RgbColor color) {
    return using((arena) {
      final ptr = ColorRgb.$allocate(arena, r: color.r, g: color.g, b: color.b);
      return ghostty_color_perceived_luminance(ptr);
    });
  }

  @override
  List<RgbColor> colorPaletteDefault() {
    return using((arena) {
      final out = arena<ColorRgb>(256);
      ghostty_color_palette_default(out);
      return _readPalette(out);
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
      final basePtr = base == null ? nullptr : arena<ColorRgb>(256);
      if (base != null) {
        for (var i = 0; i < 256; i++) {
          _writeColorRgb(basePtr[i], base[i]);
        }
      }
      final skipPtr = skip.isEmpty ? nullptr : arena<ColorPaletteMask>();
      if (skip.isNotEmpty) {
        for (var i = 0; i < 4; i++) {
          skipPtr.ref.bits[i] = 0;
        }
        for (final index in skip) {
          skipPtr.ref.bits[index >> 6] |= 1 << (index & 63);
        }
      }
      final bgPtr = ColorRgb.$allocate(
        arena,
        r: background.r,
        g: background.g,
        b: background.b,
      );
      final fgPtr = ColorRgb.$allocate(
        arena,
        r: foreground.r,
        g: foreground.g,
        b: foreground.b,
      );
      final out = arena<ColorRgb>(256);
      ghostty_color_palette_generate(
        basePtr,
        skipPtr,
        bgPtr,
        fgPtr,
        harmonious,
        out,
      );
      return _readPalette(out);
    });
  }

  @override
  CResult<RgbColor> colorParse(String value) {
    return using((arena) {
      final encoded = utf8.encode(value);
      final ptr = arena<Char>(encoded.isEmpty ? 1 : encoded.length);
      ptr.cast<Uint8>().asTypedList(encoded.length).setAll(0, encoded);
      final out = arena<ColorRgb>();
      final result = ghostty_color_parse(ptr, encoded.length, out);
      return (result, RgbColor(out.ref.r, out.ref.g, out.ref.b));
    });
  }

  @override
  CResult<({int index, RgbColor color})> colorParsePaletteEntry(String value) {
    return using((arena) {
      final encoded = utf8.encode(value);
      final ptr = arena<Char>(encoded.isEmpty ? 1 : encoded.length);
      ptr.cast<Uint8>().asTypedList(encoded.length).setAll(0, encoded);
      final outIndex = arena<Uint8>();
      final outRgb = arena<ColorRgb>();
      final result = ghostty_color_parse_palette_entry(
        ptr,
        encoded.length,
        outIndex,
        outRgb,
      );
      return (
        result,
        (
          index: outIndex.value,
          color: RgbColor(outRgb.ref.r, outRgb.ref.g, outRgb.ref.b),
        ),
      );
    });
  }

  @override
  CResult<RgbColor> colorParseX11(String name) {
    return using((arena) {
      final encoded = utf8.encode(name);
      final ptr = arena<Char>(encoded.isEmpty ? 1 : encoded.length);
      ptr.cast<Uint8>().asTypedList(encoded.length).setAll(0, encoded);
      final out = arena<ColorRgb>();
      final result = ghostty_color_parse_x11(ptr, encoded.length, out);
      return (result, RgbColor(out.ref.r, out.ref.g, out.ref.b));
    });
  }

  @override
  List<X11ColorName> colorX11Names() {
    final names = ghostty_color_x11_names();
    final count = ghostty_color_x11_name_count();
    return <X11ColorName>[
      for (var i = 0; i < count; i++)
        (
          name: names[i].name.cast<Utf8>().toDartString(),
          color: RgbColor(names[i].color.r, names[i].color.g, names[i].color.b),
        ),
    ];
  }

  @override
  CResult<String> colorSchemeReportEncode(ColorScheme scheme) {
    return using((arena) {
      final outWritten = arena<Size>();
      var result = ghostty_color_scheme_report_encode(
        scheme,
        nullptr,
        0,
        outWritten,
      );
      if (result != .outOfSpace) return (result, '');

      final bufLen = outWritten.value;
      final buf = arena<Char>(bufLen);
      result = ghostty_color_scheme_report_encode(
        scheme,
        buf,
        bufLen,
        outWritten,
      );
      final written = outWritten.value;
      return (result, utf8.decode(buf.cast<Uint8>().asTypedList(written)));
    });
  }

  @override
  int unicodeCodepointWidth(int codepoint) {
    return ghostty_unicode_codepoint_width(codepoint);
  }

  @override
  ({int consumed, int width}) unicodeGraphemeWidth(List<int> codepoints) {
    return using((arena) {
      final len = codepoints.length;
      final ptr = len == 0 ? nullptr : arena<Uint32>(len);
      for (var i = 0; i < len; i++) {
        ptr[i] = codepoints[i];
      }
      final outWidth = arena<Uint8>();
      final consumed = ghostty_unicode_grapheme_width(ptr, len, outWidth);
      return (consumed: consumed, width: outWidth.value);
    });
  }

  @override
  CResult<int> terminalNew(int cols, int rows) {
    return using((arena) {
      final ptr = arena<Pointer<TerminalImpl>>();
      final result = ghostty_terminal_new(nullptr, ptr, cols, rows);
      return (result, ptr.value.address);
    });
  }

  @override
  void terminalFree(int handle) {
    ghostty_terminal_free(Pointer.fromAddress(handle));
  }

  @override
  void terminalVtWrite(int handle, Uint8List data) {
    if (data.isEmpty) return;
    if (_callables.isEmpty) {
      using((arena) {
        final ptr = arena<Uint8>(data.length);
        ptr.asTypedList(data.length).setAll(0, data);
        ghostty_terminal_vt_write(
          Pointer.fromAddress(handle),
          ptr,
          data.length,
        );
      });
      return;
    }
    if (_callbackError != null) {
      _runNestedCallbackOperation<void>(() {
        using((arena) {
          final ptr = arena<Uint8>(data.length);
          ptr.asTypedList(data.length).setAll(0, data);
          ghostty_terminal_vt_write(
            Pointer.fromAddress(handle),
            ptr,
            data.length,
          );
        });
      });
      return;
    }
    using((arena) {
      final ptr = arena<Uint8>(data.length);
      ptr.asTypedList(data.length).setAll(0, data);
      ghostty_terminal_vt_write(Pointer.fromAddress(handle), ptr, data.length);
    });
    final failure = _callbackError;
    if (failure != null) {
      _callbackError = null;
      Error.throwWithStackTrace(failure.error, failure.stackTrace);
    }
  }

  @override
  Result terminalResize(
    int handle,
    int cols,
    int rows,
    int cellWidthPx,
    int cellHeightPx,
  ) {
    if (_callables.isEmpty) {
      return ghostty_terminal_resize(
        Pointer.fromAddress(handle),
        cols,
        rows,
        cellWidthPx,
        cellHeightPx,
      );
    }
    if (_callbackError != null) {
      return _runNestedCallbackOperation(
        () => ghostty_terminal_resize(
          Pointer.fromAddress(handle),
          cols,
          rows,
          cellWidthPx,
          cellHeightPx,
        ),
      );
    }
    final result = ghostty_terminal_resize(
      Pointer.fromAddress(handle),
      cols,
      rows,
      cellWidthPx,
      cellHeightPx,
    );
    final failure = _callbackError;
    if (failure != null) {
      _callbackError = null;
      Error.throwWithStackTrace(failure.error, failure.stackTrace);
    }
    return result;
  }

  @override
  void terminalReset(int handle) {
    ghostty_terminal_reset(Pointer.fromAddress(handle));
  }

  @override
  void terminalScrollViewport(
    int handle,
    TerminalScrollViewportTag tag,
    int value,
  ) {
    using((arena) {
      final sv = arena<TerminalScrollViewport>();
      sv.ref.tagAsInt = tag.value;
      switch (tag) {
        case .row:
          sv.ref.value.row = value;
        case .delta:
          sv.ref.value.delta = value;
        case .top || .bottom:
          sv.ref.value.delta = 0;
      }
      ghostty_terminal_scroll_viewport(Pointer.fromAddress(handle), sv.ref);
    });
  }

  @override
  CResult<int> terminalCompressionActivity(int handle) {
    _outU64.value = 0;
    final result = ghostty_terminal_compression_activity(
      Pointer.fromAddress(handle),
      _outU64,
    );
    return (result, _outU64.value);
  }

  @override
  CResult<TerminalCompressionResult> terminalCompress(
    int handle,
    TerminalCompressionMode mode,
  ) {
    _outU32.value = TerminalCompressionResult.unsupported.value;
    final result = ghostty_terminal_compress(
      Pointer.fromAddress(handle),
      mode,
      _outU32.cast(),
    );
    return (result, .fromValue(_outU32.value));
  }

  @override
  CResult<int> terminalGetCols(int handle) => _terminalGetU16(handle, .cols);

  @override
  CResult<int> terminalGetRows(int handle) => _terminalGetU16(handle, .rows);

  @override
  CResult<int> terminalGetCursorX(int handle) {
    return _terminalGetU16(handle, .cursorX);
  }

  @override
  CResult<int> terminalGetCursorY(int handle) {
    return _terminalGetU16(handle, .cursorY);
  }

  @override
  CResult<bool> terminalGetCursorVisible(int handle) {
    return _terminalGetBool(handle, .cursorVisible);
  }

  @override
  CResult<bool> terminalGetCursorPendingWrap(int handle) {
    return _terminalGetBool(handle, .cursorPendingWrap);
  }

  @override
  CResult<TerminalScreen> terminalGetActiveScreen(int handle) {
    final result = ghostty_terminal_get(
      Pointer.fromAddress(handle),
      .activeScreen,
      _outI32.cast(),
    );
    return (result, TerminalScreen.fromValue(_outI32.value));
  }

  @override
  CResult<int> terminalGetKittyKeyboardFlags(int handle) {
    final result = ghostty_terminal_get(
      Pointer.fromAddress(handle),
      .kittyKeyboardFlags,
      _outU8.cast(),
    );
    return (result, _outU8.value);
  }

  @override
  CResult<Scrollbar> terminalGetScrollbar(int handle) {
    final result = ghostty_terminal_get(
      Pointer.fromAddress(handle),
      .scrollbar,
      _outScrollbar.cast(),
    );
    return (
      result,
      Scrollbar(
        total: _outScrollbar.ref.total,
        offset: _outScrollbar.ref.offset,
        visible: _outScrollbar.ref.len,
      ),
    );
  }

  @override
  CResult<bool> terminalModeGet(int handle, int mode) {
    _outModeConfig.ref.mode = mode;
    final result = ghostty_terminal_get(
      Pointer.fromAddress(handle),
      .mode,
      _outModeConfig.cast(),
    );
    return (result, _outModeConfig.ref.value);
  }

  @override
  Result terminalModeSet(int handle, int mode, {required bool value}) {
    _outModeConfig.ref
      ..mode = mode
      ..value = value;
    return ghostty_terminal_set(
      Pointer.fromAddress(handle),
      .mode,
      _outModeConfig.cast(),
    );
  }

  @override
  Result terminalModeSetDefault(int handle, int mode, {required bool value}) {
    _outModeConfig.ref
      ..mode = mode
      ..value = value;
    return ghostty_terminal_set(
      Pointer.fromAddress(handle),
      .modeDefault,
      _outModeConfig.cast(),
    );
  }

  @override
  Result terminalSetTitleReport(int handle, {required bool enabled}) {
    return _terminalSetBool(handle, .titleReport, enabled);
  }

  @override
  CResult<String> terminalGetTitle(int handle) {
    return _terminalGetString(handle, .title);
  }

  @override
  CResult<String> terminalGetPwd(int handle) {
    return _terminalGetString(handle, .pwd);
  }

  @override
  CResult<int> terminalGetTotalRows(int handle) {
    return _terminalGetSize(handle, .totalRows);
  }

  @override
  CResult<int> terminalGetScrollbackRows(int handle) {
    return _terminalGetSize(handle, .scrollbackRows);
  }

  @override
  CResult<int> terminalGetScrollbackMaxBytes(int handle) {
    return _terminalGetSize(handle, .scrollbackMaxBytes);
  }

  @override
  CResult<int> terminalGetScrollbackMaxLines(int handle) {
    return _terminalGetSize(handle, .scrollbackMaxLines);
  }

  @override
  CResult<int> terminalGetWidthPx(int handle) {
    return _terminalGetU32(handle, .widthPx);
  }

  @override
  CResult<int> terminalGetHeightPx(int handle) {
    return _terminalGetU32(handle, .heightPx);
  }

  @override
  CResult<TerminalGeometry> terminalGetGeometry(int handle) {
    const keys = <TerminalData>[.cols, .rows, .widthPx, .heightPx];
    final result = _terminalGetMulti(handle, keys);
    if (result != .success) return (result, _emptyTerminalGeometry);
    return (
      result,
      (
        cols: (_multiOut + 0).cast<Uint16>().value,
        rows: (_multiOut + 1).cast<Uint16>().value,
        widthPx: (_multiOut + 2).cast<Uint32>().value,
        heightPx: (_multiOut + 3).cast<Uint32>().value,
      ),
    );
  }

  @override
  CResult<bool> terminalGetViewportActive(int handle) {
    return _terminalGetBool(handle, .viewportActive);
  }

  @override
  CResult<bool> terminalGetVtProcessingError(int handle) {
    return _terminalGetBool(handle, .vtProcessingError);
  }

  @override
  CResult<Uint8List> terminalContinuationGet(int handle) {
    return using((arena) {
      final outWritten = arena<Size>();
      var result = ghostty_terminal_continuation_buf(
        Pointer.fromAddress(handle),
        nullptr,
        0,
        outWritten,
      );
      if (result != .outOfSpace) return (result, Uint8List(0));

      final capacity = outWritten.value;
      if (capacity == 0) return (Result.success, Uint8List(0));
      final buffer = arena<Uint8>(capacity);
      result = ghostty_terminal_continuation_buf(
        Pointer.fromAddress(handle),
        buffer,
        capacity,
        outWritten,
      );
      if (result != .success) return (result, Uint8List(0));

      return (result, Uint8List.fromList(buffer.asTypedList(outWritten.value)));
    });
  }

  @override
  CResult<int> terminalGetContinuationMaxBytes(int handle) {
    return _terminalGetSize(handle, .continuationMaxBytes);
  }

  @override
  Result terminalSetContinuationMaxBytes(int handle, int? bytes) {
    return _terminalSetSize(handle, .continuationMaxBytes, bytes);
  }

  @override
  Result terminalSetTitle(int handle, String? title) {
    return _terminalSetString(handle, .title, title);
  }

  @override
  Result terminalSetPwd(int handle, String? pwd) {
    return _terminalSetString(handle, .pwd, pwd);
  }

  @override
  Result terminalSetDefaultCursorShape(int handle, CursorShape? shape) {
    return _terminalSetI32(handle, .defaultCursorStyle, shape?.value);
  }

  @override
  Result terminalSetDefaultCursorBlink(int handle, {bool? blinking}) {
    return _terminalSetBool(handle, .defaultCursorBlink, blinking);
  }

  @override
  Result terminalSetGlyphProtocol(int handle, {required bool enabled}) {
    return _terminalSetBool(handle, .glyphProtocol, enabled);
  }

  @override
  Result terminalSetColorForeground(int handle, RgbColor? color) {
    return _terminalSetColor(handle, .colorForeground, color);
  }

  @override
  Result terminalSetColorBackground(int handle, RgbColor? color) {
    return _terminalSetColor(handle, .colorBackground, color);
  }

  @override
  Result terminalSetColorCursor(int handle, RgbColor? color) {
    return _terminalSetColor(handle, .colorCursor, color);
  }

  @override
  Result terminalSetColorPalette(int handle, List<RgbColor>? palette) {
    if (palette == null) {
      return ghostty_terminal_set(
        Pointer.fromAddress(handle),
        TerminalOption.colorPalette,
        nullptr,
      );
    }
    return using((arena) {
      final ptr = arena<ColorRgb>(256);
      for (var i = 0; i < 256; i++) {
        ptr[i].r = palette[i].r;
        ptr[i].g = palette[i].g;
        ptr[i].b = palette[i].b;
      }
      return ghostty_terminal_set(
        Pointer.fromAddress(handle),
        TerminalOption.colorPalette,
        ptr.cast(),
      );
    });
  }

  @override
  CResult<RgbColor> terminalGetColorForeground(int handle) {
    return _terminalGetColor(handle, .colorForeground);
  }

  @override
  CResult<RgbColor> terminalGetColorBackground(int handle) {
    return _terminalGetColor(handle, .colorBackground);
  }

  @override
  CResult<RgbColor> terminalGetColorCursor(int handle) {
    return _terminalGetColor(handle, .colorCursor);
  }

  @override
  CResult<List<RgbColor>> terminalGetColorPalette(int handle) {
    return _terminalGetPalette(handle, .colorPalette);
  }

  @override
  CResult<RgbColor> terminalGetColorForegroundDefault(int handle) {
    return _terminalGetColor(handle, .colorForegroundDefault);
  }

  @override
  CResult<RgbColor> terminalGetColorBackgroundDefault(int handle) {
    return _terminalGetColor(handle, .colorBackgroundDefault);
  }

  @override
  CResult<RgbColor> terminalGetColorCursorDefault(int handle) {
    return _terminalGetColor(handle, .colorCursorDefault);
  }

  @override
  CResult<List<RgbColor>> terminalGetColorPaletteDefault(int handle) {
    return _terminalGetPalette(handle, .colorPaletteDefault);
  }

  @override
  CResult<Style> terminalGetCursorStyle(int handle) {
    return _terminalGetStyle(handle, .cursorStyle);
  }

  @override
  CResult<bool> terminalGetMouseTracking(int handle) {
    return _terminalGetBool(handle, .mouseTracking);
  }

  @override
  CResult<int> terminalGetKittyImageStorageLimit(int handle) {
    return _terminalGetU64(handle, .kittyImageStorageLimit);
  }

  @override
  CResult<bool> terminalGetKittyImageMediumFile(int handle) {
    return _terminalGetBool(handle, .kittyImageMediumFile);
  }

  @override
  CResult<String> terminalGetKittyImageMediumTempFile(int handle) {
    return _terminalGetString(handle, .kittyImageMediumTempFile);
  }

  @override
  CResult<bool> terminalGetKittyImageMediumSharedMem(int handle) {
    return _terminalGetBool(handle, .kittyImageMediumSharedMem);
  }

  @override
  Result terminalSetKittyImageStorageLimit(int handle, int? limit) {
    return _terminalSetU64(handle, .kittyImageStorageLimit, limit);
  }

  @override
  Result terminalSetKittyImageMediumFile(int handle, {bool? enabled}) {
    return _terminalSetBool(handle, .kittyImageMediumFile, enabled);
  }

  @override
  Result terminalSetKittyImageMediumTempFile(int handle, String? directory) {
    return _terminalSetString(handle, .kittyImageMediumTempFile, directory);
  }

  @override
  Result terminalSetKittyImageMediumSharedMem(int handle, {bool? enabled}) {
    return _terminalSetBool(handle, .kittyImageMediumSharedMem, enabled);
  }

  @override
  Result terminalSetApcBufferLimit(int handle, int? bytes) {
    return _terminalSetSize(handle, .apcMaxBytes, bytes);
  }

  @override
  Result terminalSetKittyApcBufferLimit(int handle, int? bytes) {
    return _terminalSetSize(handle, .apcMaxBytesKitty, bytes);
  }

  @override
  Result terminalSetScrollbackMaxBytes(int handle, int? bytes) {
    return _terminalSetSize(handle, .scrollbackMaxBytes, bytes);
  }

  @override
  Result terminalSetScrollbackMaxLines(int handle, int? lines) {
    return _terminalSetSize(handle, .scrollbackMaxLines, lines);
  }

  @override
  CResult<Uint8List> pasteEncode(String data, {required bool bracketed}) {
    return using((arena) {
      final encoded = utf8.encode(data);
      final dataPtr = arena<Char>(encoded.length);
      dataPtr.cast<Uint8>().asTypedList(encoded.length).setAll(0, encoded);
      final outWritten = arena<Size>();

      // First call to get the required buffer size.
      var result = ghostty_paste_encode(
        dataPtr,
        encoded.length,
        bracketed,
        nullptr,
        0,
        outWritten,
      );

      if (result != .outOfSpace) return (result, Uint8List(0));

      final bufLen = outWritten.value;
      final buf = arena<Char>(bufLen);

      // Re-encode the data since the first call modified it in place.
      dataPtr.cast<Uint8>().asTypedList(encoded.length).setAll(0, encoded);

      result = ghostty_paste_encode(
        dataPtr,
        encoded.length,
        bracketed,
        buf,
        bufLen,
        outWritten,
      );

      final written = outWritten.value;
      return (
        result,
        Uint8List.fromList(buf.cast<Uint8>().asTypedList(written)),
      );
    });
  }

  @override
  CResult<int> renderStateNew() {
    return using((arena) {
      final ptr = arena<Pointer<RenderStateImpl>>();
      final result = ghostty_render_state_new(nullptr, ptr);
      return (result, ptr.value.address);
    });
  }

  @override
  void renderStateFree(int handle) {
    ghostty_render_state_free(Pointer.fromAddress(handle));
  }

  @override
  Result renderStateBeginUpdate(int state, int terminal) {
    return ghostty_render_state_begin_update(
      Pointer.fromAddress(state),
      Pointer.fromAddress(terminal),
    );
  }

  @override
  Result renderStateEndUpdate(int state) {
    return ghostty_render_state_end_update(Pointer.fromAddress(state));
  }

  @override
  Result renderStateUpdate(int state, int terminal) {
    return ghostty_render_state_update(
      Pointer.fromAddress(state),
      Pointer.fromAddress(terminal),
    );
  }

  @override
  CResult<int> renderStateGetCols(int state) {
    return _renderStateGetU16(state, .cols);
  }

  @override
  CResult<int> renderStateGetRows(int state) {
    return _renderStateGetU16(state, .rows);
  }

  @override
  CResult<RenderStateDirty> renderStateGetDirty(int state) {
    final result = ghostty_render_state_get(
      Pointer.fromAddress(state),
      RenderStateData.dirty,
      _outI32.cast(),
    );
    return (result, .fromValue(_outI32.value));
  }

  @override
  CResult<RawRenderStateSummary> renderStateGetSummary(int state) {
    final result = ghostty_render_state_get_multi(
      Pointer.fromAddress(state),
      _renderStateSummaryKeys.length,
      _renderStateSummaryMultiKeys,
      _renderStateSummaryMultiValues,
      _outSize,
    );
    if (result != .success) return (result, _emptyRenderStateSummary);
    return (
      result,
      (
        cols: (_renderStateSummaryMultiOut + 0).cast<Uint16>().value,
        rows: (_renderStateSummaryMultiOut + 1).cast<Uint16>().value,
        dirty: .fromValue(
          (_renderStateSummaryMultiOut + 2).cast<Int32>().value,
        ),
      ),
    );
  }

  @override
  Result renderStateSetDirty(int state, RenderStateDirty dirty) {
    _outI32.value = dirty.value;
    return ghostty_render_state_set(
      Pointer.fromAddress(state),
      RenderStateOption.dirty,
      _outI32.cast(),
    );
  }

  @override
  CResult<TerminalColors> renderStateGetColors(int state) {
    final result = ghostty_render_state_colors_get(
      Pointer.fromAddress(state),
      _outColors,
    );

    final ref = _outColors.ref;
    return (
      result,
      TerminalColors(
        foreground: RgbColor(
          ref.foreground.r,
          ref.foreground.g,
          ref.foreground.b,
        ),
        background: RgbColor(
          ref.background.r,
          ref.background.g,
          ref.background.b,
        ),
        cursor: ref.cursor_has_value
            ? RgbColor(ref.cursor.r, ref.cursor.g, ref.cursor.b)
            : null,
        palette: [
          for (var i = 0; i < 256; i++)
            RgbColor(ref.palette[i].r, ref.palette[i].g, ref.palette[i].b),
        ],
      ),
    );
  }

  @override
  CResult<RenderStateCursorVisualStyle> renderStateGetCursorVisualStyle(
    int state,
  ) {
    final result = ghostty_render_state_get(
      Pointer.fromAddress(state),
      RenderStateData.cursorVisualStyle,
      _outI32.cast(),
    );
    return (result, RenderStateCursorVisualStyle.fromValue(_outI32.value));
  }

  @override
  CResult<bool> renderStateGetCursorVisible(int state) {
    return _renderStateGetBool(state, .cursorVisible);
  }

  @override
  CResult<bool> renderStateGetCursorBlinking(int state) {
    return _renderStateGetBool(state, .cursorBlinking);
  }

  @override
  CResult<bool> renderStateGetCursorPasswordInput(int state) {
    return _renderStateGetBool(state, .cursorPasswordInput);
  }

  @override
  CResult<bool> renderStateGetCursorInViewport(int state) {
    return _renderStateGetBool(state, .cursorViewportHasValue);
  }

  @override
  CResult<int> renderStateGetCursorViewportX(int state) {
    return _renderStateGetU16(state, .cursorViewportX);
  }

  @override
  CResult<int> renderStateGetCursorViewportY(int state) {
    return _renderStateGetU16(state, .cursorViewportY);
  }

  @override
  CResult<bool> renderStateGetCursorViewportWideTail(int state) {
    return _renderStateGetBool(state, .cursorViewportWideTail);
  }

  @override
  CResult<RawRenderStateCursor> renderStateGetCursor(int state) {
    final result = ghostty_render_state_get_multi(
      Pointer.fromAddress(state),
      _cursorStateKeys.length,
      _cursorMultiKeys,
      _cursorMultiValues,
      _outSize,
    );
    final written = _outSize.value;
    final cursorOffscreen = result == .invalidValue && written == 5;
    if (result != .success && !cursorOffscreen) {
      return (result, _emptyRenderStateCursor);
    }
    final visualStyle = RenderStateCursorVisualStyle.fromValue(
      (_cursorMultiOut + 0).cast<Int32>().value,
    );
    final visible = (_cursorMultiOut + 1).cast<Bool>().value;
    final blinking = (_cursorMultiOut + 2).cast<Bool>().value;
    final passwordInput = (_cursorMultiOut + 3).cast<Bool>().value;
    final inViewport = (_cursorMultiOut + 4).cast<Bool>().value;
    if (!inViewport) {
      return (
        .success,
        (
          visualStyle: visualStyle,
          visible: visible,
          blinking: blinking,
          passwordInput: passwordInput,
          inViewport: false,
          viewportX: 0,
          viewportY: 0,
          viewportWideTail: false,
        ),
      );
    }

    return (
      result,
      (
        visualStyle: visualStyle,
        visible: visible,
        blinking: blinking,
        passwordInput: passwordInput,
        inViewport: true,
        viewportX: (_cursorMultiOut + 5).cast<Uint16>().value,
        viewportY: (_cursorMultiOut + 6).cast<Uint16>().value,
        viewportWideTail: (_cursorMultiOut + 7).cast<Bool>().value,
      ),
    );
  }

  @override
  CResult<int> rowIteratorNew() {
    return using((arena) {
      final ptr = arena<Pointer<RenderStateRowIteratorImpl>>();
      final result = ghostty_render_state_row_iterator_new(nullptr, ptr);
      return (result, ptr.value.address);
    });
  }

  @override
  void rowIteratorFree(int handle) {
    ghostty_render_state_row_iterator_free(Pointer.fromAddress(handle));
  }

  @override
  Result rowIteratorInit(int iterator, int renderState) {
    return using((arena) {
      final ptr = arena<Pointer<RenderStateRowIterator>>();
      ptr.value = Pointer.fromAddress(iterator);
      return ghostty_render_state_get(
        Pointer.fromAddress(renderState),
        RenderStateData.rowIterator,
        ptr.cast(),
      );
    });
  }

  @override
  bool rowIteratorNext(int iterator) {
    return ghostty_render_state_row_iterator_next(
      Pointer.fromAddress(iterator),
    );
  }

  @override
  CResult<bool> rowIteratorGetDirty(int iterator) {
    final result = ghostty_render_state_row_get(
      Pointer.fromAddress(iterator),
      RenderStateRowData.dirty,
      _outBool.cast(),
    );
    return (result, _outBool.value);
  }

  @override
  CResult<RawRowIteratorSummary> rowIteratorGetSummary(int iterator) {
    const keys = _rowIteratorSummaryKeys;
    for (var i = 0; i < keys.length; i++) {
      _multiKeys[i] = keys[i].value;
      _multiValues[i] = (_multiOut + i).cast();
    }
    final result = ghostty_render_state_row_get_multi(
      Pointer.fromAddress(iterator),
      keys.length,
      _multiKeys,
      _multiValues,
      _outSize,
    );
    return (
      result,
      (
        dirty: (_multiOut + 0).cast<Bool>().value,
        rawRow: (_multiOut + 1).value,
      ),
    );
  }

  @override
  Result rowIteratorSetDirty(int iterator, {required bool dirty}) {
    _outBool.value = dirty;
    return ghostty_render_state_row_set(
      Pointer.fromAddress(iterator),
      RenderStateRowOption.dirty,
      _outBool.cast(),
    );
  }

  @override
  CResult<int> rowIteratorGetRawRow(int iterator) {
    final result = ghostty_render_state_row_get(
      Pointer.fromAddress(iterator),
      RenderStateRowData.raw,
      _outU64.cast(),
    );
    return (result, _outU64.value);
  }

  @override
  CResult<({int startCol, int endCol})> rowIteratorGetSelection(int iterator) {
    return using((arena) {
      final selection = RenderStateRowSelection.$allocate(
        arena,
        size: sizeOf<RenderStateRowSelection>(),
        start_x: 0,
        end_x: 0,
      );
      final result = ghostty_render_state_row_get(
        Pointer.fromAddress(iterator),
        RenderStateRowData.selection,
        selection.cast(),
      );
      return (
        result,
        (startCol: selection.ref.start_x, endCol: selection.ref.end_x),
      );
    });
  }

  @override
  CResult<int> rowCellsNew() {
    return using((arena) {
      final ptr = arena<Pointer<RenderStateRowCellsImpl>>();
      final result = ghostty_render_state_row_cells_new(nullptr, ptr);
      return (result, ptr.value.address);
    });
  }

  @override
  void rowCellsFree(int handle) {
    ghostty_render_state_row_cells_free(Pointer.fromAddress(handle));
  }

  @override
  Result rowCellsInit(int cells, int iterator) {
    return using((arena) {
      final ptr = arena<Pointer<RenderStateRowCells>>();
      ptr.value = Pointer.fromAddress(cells);
      return ghostty_render_state_row_get(
        Pointer.fromAddress(iterator),
        RenderStateRowData.cells,
        ptr.cast(),
      );
    });
  }

  @override
  bool rowCellsNext(int cells) {
    return ghostty_render_state_row_cells_next(Pointer.fromAddress(cells));
  }

  @override
  Result rowCellsSelect(int cells, int x) {
    return ghostty_render_state_row_cells_select(Pointer.fromAddress(cells), x);
  }

  @override
  CResult<int> rowCellsGetRawCell(int cells) {
    final result = ghostty_render_state_row_cells_get(
      Pointer.fromAddress(cells),
      RenderStateRowCellsData.raw,
      _outU64.cast(),
    );
    return (result, _outU64.value);
  }

  @override
  CResult<RawRowCellsSummary> rowCellsGetSummary(int cells) {
    final result = ghostty_render_state_row_cells_get_multi(
      Pointer.fromAddress(cells),
      _rowCellsSummaryKeys.length,
      _rowCellsMultiKeys,
      _rowCellsMultiValues,
      _outSize,
    );
    return (
      result,
      (
        rawCell: (_rowCellsMultiOut + 0).value,
        graphemeLen: (_rowCellsMultiOut + 1).cast<Uint32>().value,
        selected: (_rowCellsMultiOut + 2).cast<Bool>().value,
      ),
    );
  }

  @override
  CResult<Style> rowCellsGetStyle(int cells) {
    final result = ghostty_render_state_row_cells_get(
      Pointer.fromAddress(cells),
      RenderStateRowCellsData.style,
      _outStyle.cast(),
    );
    return (result, _readNativeStyle(_outStyle.ref));
  }

  @override
  CResult<int> rowCellsGetGraphemeLen(int cells) {
    final result = ghostty_render_state_row_cells_get(
      Pointer.fromAddress(cells),
      RenderStateRowCellsData.graphemesLen,
      _outU32.cast(),
    );
    return (result, _outU32.value);
  }

  @override
  CResult<List<int>> rowCellsGetGraphemes(int cells, int len) {
    if (len <= 0) return (Result.success, const []);
    final buf = len <= 32 ? _graphemeBuf : calloc<Uint32>(len);
    final result = ghostty_render_state_row_cells_get(
      Pointer.fromAddress(cells),
      RenderStateRowCellsData.graphemesBuf,
      buf.cast(),
    );
    final graphemes = [for (var i = 0; i < len; i++) buf[i]];
    if (len > 32) calloc.free(buf);
    return (result, graphemes);
  }

  @override
  CResult<String> rowCellsGetGraphemesUtf8(int cells) {
    return using((arena) {
      const inlineCap = 64;
      var data = arena<Uint8>(inlineCap);
      final buffer = Buffer.$allocate(arena, ptr: data, cap: inlineCap, len: 0);

      var result = ghostty_render_state_row_cells_get(
        Pointer.fromAddress(cells),
        RenderStateRowCellsData.graphemesUtf8,
        buffer.cast(),
      );
      var len = buffer.ref.len;

      if (result == Result.outOfSpace) {
        data = arena<Uint8>(len);
        buffer.ref
          ..ptr = data
          ..cap = len
          ..len = 0;
        result = ghostty_render_state_row_cells_get(
          Pointer.fromAddress(cells),
          RenderStateRowCellsData.graphemesUtf8,
          buffer.cast(),
        );
        len = buffer.ref.len;
      }

      return (result, len == 0 ? '' : utf8.decode(data.asTypedList(len)));
    });
  }

  @override
  CResult<bool> rowCellsGetHasStyling(int cells) {
    final result = ghostty_render_state_row_cells_get(
      Pointer.fromAddress(cells),
      RenderStateRowCellsData.hasStyling,
      _outBool.cast(),
    );
    return (result, _outBool.value);
  }

  @override
  CResult<bool> rowCellsGetSelected(int cells) {
    final result = ghostty_render_state_row_cells_get(
      Pointer.fromAddress(cells),
      RenderStateRowCellsData.selected,
      _outBool.cast(),
    );
    return (result, _outBool.value);
  }

  @override
  CResult<RgbColor> rowCellsGetBgColor(int cells) {
    final result = ghostty_render_state_row_cells_get(
      Pointer.fromAddress(cells),
      RenderStateRowCellsData.bgColor,
      _outColorRgb.cast(),
    );
    return (
      result,
      RgbColor(_outColorRgb.ref.r, _outColorRgb.ref.g, _outColorRgb.ref.b),
    );
  }

  @override
  CResult<RgbColor> rowCellsGetFgColor(int cells) {
    final result = ghostty_render_state_row_cells_get(
      Pointer.fromAddress(cells),
      RenderStateRowCellsData.fgColor,
      _outColorRgb.cast(),
    );
    return (
      result,
      RgbColor(_outColorRgb.ref.r, _outColorRgb.ref.g, _outColorRgb.ref.b),
    );
  }

  @override
  CResult<int> rowCellsGetBgColorArgb(int cells) {
    final result = ghostty_render_state_row_cells_get(
      Pointer.fromAddress(cells),
      .bgColor,
      _outColorRgb.cast(),
    );
    final color = _outColorRgb.ref;
    return (result, 0xFF000000 | (color.r << 16) | (color.g << 8) | color.b);
  }

  @override
  CResult<int> rowCellsGetFgColorArgb(int cells) {
    final result = ghostty_render_state_row_cells_get(
      Pointer.fromAddress(cells),
      .fgColor,
      _outColorRgb.cast(),
    );
    final color = _outColorRgb.ref;
    return (result, 0xFF000000 | (color.r << 16) | (color.g << 8) | color.b);
  }

  @override
  CResult<int> cellGetCodepoint(int cell) => _cellGetU32(cell, .codepoint);

  @override
  CResult<RawCellSummary> cellGetSummary(int cell) {
    final result = ghostty_cell_get_multi(
      cell,
      _cellSummaryKeys.length,
      _cellMultiKeys,
      _cellMultiValues,
      _outSize,
    );
    return (
      result,
      (
        codepoint: (_cellMultiOut + 0).cast<Uint32>().value,
        styleId: (_cellMultiOut + 1).cast<Uint16>().value,
        wide: .fromValue((_cellMultiOut + 2).cast<Int32>().value),
      ),
    );
  }

  @override
  CResult<CellContentTag> cellGetContentTag(int cell) {
    final raw = _cellGetI32(cell, .contentTag);
    return (raw.$1, CellContentTag.fromValue(raw.$2));
  }

  @override
  CResult<CellWide> cellGetWide(int cell) {
    final raw = _cellGetI32(cell, .wide);
    return (raw.$1, CellWide.fromValue(raw.$2));
  }

  @override
  CResult<bool> cellGetHasText(int cell) => _cellGetBool(cell, .hasText);

  @override
  CResult<bool> cellGetHasStyling(int cell) => _cellGetBool(cell, .hasStyling);

  @override
  CResult<int> cellGetStyleId(int cell) {
    final result = ghostty_cell_get(cell, .styleId, _outU16.cast());
    return (result, _outU16.value);
  }

  @override
  CResult<bool> cellGetHasHyperlink(int cell) {
    return _cellGetBool(cell, .hasHyperlink);
  }

  @override
  CResult<bool> cellGetProtected(int cell) => _cellGetBool(cell, .protected);

  @override
  CResult<CellSemanticContent> cellGetSemanticContent(int cell) {
    final raw = _cellGetI32(cell, .semanticContent);
    return (raw.$1, CellSemanticContent.fromValue(raw.$2));
  }

  @override
  CResult<int> cellGetColorPalette(int cell) {
    final result = ghostty_cell_get(cell, .colorPalette, _outU8.cast());
    return (result, _outU8.value);
  }

  @override
  CResult<RgbColor> cellGetColorRgb(int cell) {
    return using((arena) {
      final out = arena<ColorRgb>();
      final result = ghostty_cell_get(cell, .colorRgb, out.cast());
      return (result, RgbColor(out.ref.r, out.ref.g, out.ref.b));
    });
  }

  @override
  CResult<bool> rowGetWrap(int row) => _rowGetBool(row, .wrap);

  @override
  CResult<bool> rowGetWrapContinuation(int row) {
    return _rowGetBool(row, .wrapContinuation);
  }

  @override
  CResult<bool> rowGetGrapheme(int row) => _rowGetBool(row, .grapheme);

  @override
  CResult<bool> rowGetStyled(int row) => _rowGetBool(row, .styled);

  @override
  CResult<bool> rowGetHyperlink(int row) => _rowGetBool(row, .hyperlink);

  @override
  CResult<RowSemanticPrompt> rowGetSemanticPrompt(int row) {
    final result = ghostty_row_get(row, .semanticPrompt, _outI32.cast());
    return (result, RowSemanticPrompt.fromValue(_outI32.value));
  }

  @override
  CResult<bool> rowGetKittyVirtualPlaceholder(int row) {
    return _rowGetBool(row, .kittyVirtualPlaceholder);
  }

  @override
  CResult<bool> rowGetDirty(int row) => _rowGetBool(row, .dirty);

  @override
  CResult<RawRowSummary> rowGetSummary(int row) {
    const keys = _rowSummaryKeys;
    for (var i = 0; i < keys.length; i++) {
      _multiKeys[i] = keys[i].value;
      _multiValues[i] = (_multiOut + i).cast();
    }
    final result = ghostty_row_get_multi(
      row,
      keys.length,
      _multiKeys,
      _multiValues,
      _outSize,
    );
    return (
      result,
      (
        wrap: (_multiOut + 0).cast<Bool>().value,
        wrapContinuation: (_multiOut + 1).cast<Bool>().value,
        grapheme: (_multiOut + 2).cast<Bool>().value,
        styled: (_multiOut + 3).cast<Bool>().value,
        hyperlink: (_multiOut + 4).cast<Bool>().value,
        semanticPrompt: .fromValue((_multiOut + 5).cast<Int32>().value),
        kittyVirtualPlaceholder: (_multiOut + 6).cast<Bool>().value,
      ),
    );
  }

  @override
  CResult<String> focusEncode(FocusEvent event) {
    return using((arena) {
      final outLen = arena<Size>();
      final buf = arena<Char>(8);
      final result = ghostty_focus_encode(event, buf, 8, outLen);
      final len = outLen.value;
      final encoded = len == 0
          ? ''
          : utf8.decode(buf.cast<Uint8>().asTypedList(len));
      return (result, encoded);
    });
  }

  CResult<int> _terminalGetU16(int handle, TerminalData data) {
    final result = ghostty_terminal_get(
      Pointer.fromAddress(handle),
      data,
      _outU16.cast(),
    );
    return (result, _outU16.value);
  }

  CResult<int> _terminalGetU32(int handle, TerminalData data) {
    final result = ghostty_terminal_get(
      Pointer.fromAddress(handle),
      data,
      _outU32.cast(),
    );
    return (result, _outU32.value);
  }

  CResult<int> _terminalGetSize(int handle, TerminalData data) {
    final result = ghostty_terminal_get(
      Pointer.fromAddress(handle),
      data,
      _outSize.cast(),
    );
    return (result, _outSize.value);
  }

  CResult<String> _terminalGetString(int handle, TerminalData data) {
    final result = ghostty_terminal_get(
      Pointer.fromAddress(handle),
      data,
      _outGhosttyString.cast(),
    );
    if (result != .success) return (result, '');
    final ptr = _outGhosttyString.ref.ptr;
    final len = _outGhosttyString.ref.len;
    if (len == 0 || ptr == nullptr) return (result, '');
    return (result, utf8.decode(ptr.asTypedList(len)));
  }

  Result _terminalSetString(int handle, TerminalOption option, String? value) {
    if (value == null) {
      return ghostty_terminal_set(Pointer.fromAddress(handle), option, nullptr);
    }
    return using((arena) {
      final encoded = utf8.encode(value);
      final bytesPtr = arena<Uint8>(encoded.length);
      bytesPtr.asTypedList(encoded.length).setAll(0, encoded);
      final strPtr = native.String.$allocate(
        arena,
        ptr: bytesPtr,
        len: encoded.length,
      );
      return ghostty_terminal_set(
        Pointer.fromAddress(handle),
        option,
        strPtr.cast(),
      );
    });
  }

  CResult<bool> _terminalGetBool(int handle, TerminalData data) {
    final result = ghostty_terminal_get(
      Pointer.fromAddress(handle),
      data,
      _outBool.cast(),
    );
    return (result, _outBool.value);
  }

  CResult<int> _terminalGetU64(int handle, TerminalData data) {
    final result = ghostty_terminal_get(
      Pointer.fromAddress(handle),
      data,
      _outU64.cast(),
    );
    return (result, _outU64.value);
  }

  CResult<Style> _terminalGetStyle(int handle, TerminalData data) {
    final result = ghostty_terminal_get(
      Pointer.fromAddress(handle),
      data,
      _outStyle.cast(),
    );
    return (result, _readNativeStyle(_outStyle.ref));
  }

  Result _terminalSetBool(int handle, TerminalOption option, bool? value) {
    if (value == null) {
      return ghostty_terminal_set(Pointer.fromAddress(handle), option, nullptr);
    }
    _outBool.value = value;
    return ghostty_terminal_set(
      Pointer.fromAddress(handle),
      option,
      _outBool.cast(),
    );
  }

  Result _terminalSetI32(int handle, TerminalOption option, int? value) {
    if (value == null) {
      return ghostty_terminal_set(Pointer.fromAddress(handle), option, nullptr);
    }
    _outI32.value = value;
    return ghostty_terminal_set(
      Pointer.fromAddress(handle),
      option,
      _outI32.cast(),
    );
  }

  Result _terminalSetU64(int handle, TerminalOption option, int? value) {
    if (value == null) {
      return ghostty_terminal_set(Pointer.fromAddress(handle), option, nullptr);
    }
    _outU64.value = value;
    return ghostty_terminal_set(
      Pointer.fromAddress(handle),
      option,
      _outU64.cast(),
    );
  }

  Result _terminalSetSize(int handle, TerminalOption option, int? value) {
    if (value == null) {
      return ghostty_terminal_set(Pointer.fromAddress(handle), option, nullptr);
    }
    _outSize.value = value;
    return ghostty_terminal_set(
      Pointer.fromAddress(handle),
      option,
      _outSize.cast(),
    );
  }

  CResult<RgbColor> _terminalGetColor(int handle, TerminalData data) {
    final result = ghostty_terminal_get(
      Pointer.fromAddress(handle),
      data,
      _outColorRgb.cast(),
    );
    return (
      result,
      RgbColor(_outColorRgb.ref.r, _outColorRgb.ref.g, _outColorRgb.ref.b),
    );
  }

  CResult<List<RgbColor>> _terminalGetPalette(int handle, TerminalData data) {
    return using((arena) {
      final ptr = arena<ColorRgb>(256);
      final result = ghostty_terminal_get(
        Pointer.fromAddress(handle),
        data,
        ptr.cast(),
      );

      if (result != .success) return (result, const <RgbColor>[]);

      return (
        result,
        <RgbColor>[
          for (var i = 0; i < 256; i++) RgbColor(ptr[i].r, ptr[i].g, ptr[i].b),
        ],
      );
    });
  }

  Result _terminalSetColor(int handle, TerminalOption option, RgbColor? color) {
    if (color == null) {
      return ghostty_terminal_set(Pointer.fromAddress(handle), option, nullptr);
    }
    _outColorRgb.ref.r = color.r;
    _outColorRgb.ref.g = color.g;
    _outColorRgb.ref.b = color.b;
    return ghostty_terminal_set(
      Pointer.fromAddress(handle),
      option,
      _outColorRgb.cast(),
    );
  }

  CResult<int> _renderStateGetU16(int state, RenderStateData data) {
    final result = ghostty_render_state_get(
      Pointer.fromAddress(state),
      data,
      _outU16.cast(),
    );
    return (result, _outU16.value);
  }

  CResult<bool> _renderStateGetBool(int state, RenderStateData data) {
    final result = ghostty_render_state_get(
      Pointer.fromAddress(state),
      data,
      _outBool.cast(),
    );
    return (result, _outBool.value);
  }

  Result _terminalGetMulti(int handle, List<TerminalData> keys) {
    for (var i = 0; i < keys.length; i++) {
      _multiKeys[i] = keys[i].value;
      _multiValues[i] = (_multiOut + i).cast();
    }
    return ghostty_terminal_get_multi(
      Pointer.fromAddress(handle),
      keys.length,
      _multiKeys,
      _multiValues,
      _outSize,
    );
  }

  void _growFormatBuffer(int capacity) {
    if (capacity <= _formatBufferCapacity) return;
    final replacement = calloc<Uint8>(capacity);
    calloc.free(_formatBuffer);
    _formatBuffer = replacement;
    _formatBufferCapacity = capacity;
  }

  CResult<int> _cellGetU32(int cell, CellData data) {
    final result = ghostty_cell_get(cell, data, _outU32.cast());
    return (result, _outU32.value);
  }

  CResult<int> _cellGetI32(int cell, CellData data) {
    final result = ghostty_cell_get(cell, data, _outI32.cast());
    return (result, _outI32.value);
  }

  CResult<bool> _cellGetBool(int cell, CellData data) {
    final result = ghostty_cell_get(cell, data, _outBool.cast());
    return (result, _outBool.value);
  }

  CResult<bool> _rowGetBool(int row, RowData data) {
    final result = ghostty_row_get(row, data, _outBool.cast());
    return (result, _outBool.value);
  }

  String? _extractWindowTitle(OscCommand commandPtr) {
    return using((arena) {
      final outPtr = arena<Pointer<Char>>();
      final success = ghostty_osc_command_data(
        commandPtr,
        OscCommandData.changeWindowTitleStr,
        outPtr.cast(),
      );
      if (!success) return null;
      final charPtr = outPtr.value;
      if (charPtr == nullptr) return null;
      return charPtr.cast<Utf8>().toDartString();
    });
  }

  static Style _readNativeStyle(native.Style s) {
    final rawUnderlineColor = _readNativeColor(s.underline_color);
    return Style(
      foreground: cellColorFromRaw(_readNativeColor(s.fg_color)),
      background: cellColorFromRaw(_readNativeColor(s.bg_color)),
      underlineColor: switch (rawUnderlineColor.tag) {
        .rgb || .palette => cellColorFromRaw(rawUnderlineColor),
        .none => null,
      },
      bold: s.bold,
      italic: s.italic,
      faint: s.faint,
      blink: s.blink,
      inverse: s.inverse,
      invisible: s.invisible,
      strikethrough: s.strikethrough,
      overline: s.overline,
      underline: UnderlineStyle.fromValue(s.underline),
    );
  }

  static RawColor _readNativeColor(StyleColor c) => (
    tag: StyleColorTag.fromValue(c.tag.value),
    palette: c.value.palette,
    r: c.value.rgb.r,
    g: c.value.rgb.g,
    b: c.value.rgb.b,
  );

  static List<RgbColor> _readPalette(Pointer<ColorRgb> ptr) => <RgbColor>[
    for (var i = 0; i < 256; i++) RgbColor(ptr[i].r, ptr[i].g, ptr[i].b),
  ];

  static void _writeColorRgb(ColorRgb ref, RgbColor color) {
    ref.r = color.r;
    ref.g = color.g;
    ref.b = color.b;
  }

  static void _writeNativeColor(StyleColor ref, RawColor color) {
    ref.tagAsInt = color.tag.value;
    ref.value.palette = color.palette;
    ref.value.rgb.r = color.r;
    ref.value.rgb.g = color.g;
    ref.value.rgb.b = color.b;
  }

  static void _writePoint(Point target, PointTag pointTag, Position position) {
    target.tagAsInt = pointTag.value;
    target.value.coordinate.x = position.col;
    target.value.coordinate.y = position.row;
  }

  static RawGridRef _readGridRef(GridRef ref) {
    return (node: ref.node.address, x: ref.x, y: ref.y);
  }

  static void _writeGridRef(GridRef target, RawGridRef ref) {
    target
      ..size = sizeOf<GridRef>()
      ..node = Pointer<Void>.fromAddress(ref.node)
      ..x = ref.x
      ..y = ref.y;
  }

  static RawSelection _readSelection(Selection selection) {
    return (
      start: _readGridRef(selection.start),
      end: _readGridRef(selection.end),
      rectangle: selection.rectangle,
    );
  }

  static void _writeSelection(Selection target, RawSelection selection) {
    target.size = sizeOf<Selection>();
    _writeGridRef(target.start, selection.start);
    _writeGridRef(target.end, selection.end);
    target.rectangle = selection.rectangle;
  }

  static Pointer<Uint32> _writeCodepoints(Arena arena, List<int>? codepoints) {
    if (codepoints == null) return nullptr;
    final ptr = arena<Uint32>(codepoints.isEmpty ? 1 : codepoints.length);
    for (var i = 0; i < codepoints.length; i++) {
      ptr[i] = codepoints[i];
    }
    return ptr;
  }

  static RawColor _cellColorToRaw(CellColor color) => switch (color) {
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

  void _freeUtf8(int handle) {
    final ptr = _utf8Ptrs.remove(handle);
    if (ptr != null) calloc.free(ptr);
  }

  SgrAttribute _convertNativeSgrAttribute(native.SgrAttribute attr) {
    final tag = SgrAttributeTag.fromValue(attr.tagAsInt);
    final value = attr.value;
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
        underlineStyle: UnderlineStyle.fromValue(value.underlineAsInt),
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

  @override
  CResult<int> buildInfo(BuildInfo data) {
    final result = ghostty_build_info(data, _outSize.cast());
    return (result, _outSize.value);
  }

  @override
  CResult<bool> buildInfoBool(BuildInfo data) {
    final result = ghostty_build_info(data, _outBool.cast());
    return (result, _outBool.value);
  }

  @override
  CResult<String> buildInfoString(BuildInfo data) {
    final result = ghostty_build_info(data, _outGhosttyString.cast());
    final ptr = _outGhosttyString.ref.ptr;
    final len = _outGhosttyString.ref.len;
    if (len == 0 || ptr == nullptr) return (result, '');
    return (result, utf8.decode(ptr.asTypedList(len)));
  }

  @override
  CResult<String> modeReportEncode(int mode, ModeReportState state) {
    return using((arena) {
      final outLen = arena<Size>();
      final buf = arena<Char>(64);
      final result = ghostty_mode_report_encode(mode, state, buf, 64, outLen);
      final len = outLen.value;
      final encoded = len == 0
          ? ''
          : utf8.decode(buf.cast<Uint8>().asTypedList(len));
      return (result, encoded);
    });
  }

  @override
  CResult<String> sizeReportEncode(
    SizeReportStyle style,
    int rows,
    int columns,
    int cellWidth,
    int cellHeight,
  ) {
    return using((arena) {
      final outLen = arena<Size>();
      final buf = arena<Char>(64);
      final size = SizeReportSize.$allocate(
        arena,
        rows: rows,
        columns: columns,
        cell_width: cellWidth,
        cell_height: cellHeight,
      );
      final result = ghostty_size_report_encode(
        style,
        size.ref,
        buf,
        64,
        outLen,
      );
      final len = outLen.value;
      final encoded = len == 0
          ? ''
          : utf8.decode(buf.cast<Uint8>().asTypedList(len));
      return (result, encoded);
    });
  }

  @override
  Style styleDefault() {
    return using((arena) {
      final style = arena<native.Style>();
      style.ref.size = sizeOf<native.Style>();
      ghostty_style_default(style);
      return _readNativeStyle(style.ref);
    });
  }

  @override
  bool styleIsDefault(Style style) {
    return using((arena) {
      final s = arena<native.Style>();
      s.ref.size = sizeOf<native.Style>();
      _writeNativeColor(s.ref.fg_color, _cellColorToRaw(style.foreground));
      _writeNativeColor(s.ref.bg_color, _cellColorToRaw(style.background));
      _writeNativeColor(
        s.ref.underline_color,
        style.underlineColor != null
            ? _cellColorToRaw(style.underlineColor!)
            : defaultRawColor,
      );
      s.ref.bold = style.bold;
      s.ref.italic = style.italic;
      s.ref.faint = style.faint;
      s.ref.blink = style.blink;
      s.ref.inverse = style.inverse;
      s.ref.invisible = style.invisible;
      s.ref.strikethrough = style.strikethrough;
      s.ref.overline = style.overline;
      s.ref.underline = style.underline.value;
      return ghostty_style_is_default(s);
    });
  }

  @override
  CResult<RawGridRef> terminalGridRef(
    int terminal,
    PointTag pointTag,
    Position position,
  ) {
    return using((arena) {
      final point = arena<Point>();
      _writePoint(point.ref, pointTag, position);
      final gridRef = arena<GridRef>();
      gridRef.ref.size = sizeOf<GridRef>();
      final result = ghostty_terminal_grid_ref(
        Pointer.fromAddress(terminal),
        point.ref,
        gridRef,
      );
      return (result, _readGridRef(gridRef.ref));
    });
  }

  @override
  CResult<int> terminalGridRefTrack(
    int terminal,
    PointTag pointTag,
    Position position,
  ) {
    return using((arena) {
      final point = arena<Point>();
      final out = arena<Pointer<TrackedGridRefImpl>>();
      _writePoint(point.ref, pointTag, position);
      final result = ghostty_terminal_grid_ref_track(
        Pointer.fromAddress(terminal),
        point.ref,
        out,
      );
      return (result, out.value.address);
    });
  }

  @override
  @override
  CResult<int> gridRefCell(RawGridRef ref) {
    return using((arena) {
      final gridRef = GridRef.$allocate(
        arena,
        size: sizeOf<GridRef>(),
        node: Pointer<Void>.fromAddress(ref.node),
        x: ref.x,
        y: ref.y,
      );
      final result = ghostty_grid_ref_cell(gridRef, _outU64.cast());
      return (result, _outU64.value);
    });
  }

  @override
  CResult<int> gridRefRow(RawGridRef ref) {
    return using((arena) {
      final gridRef = GridRef.$allocate(
        arena,
        size: sizeOf<GridRef>(),
        node: Pointer<Void>.fromAddress(ref.node),
        x: ref.x,
        y: ref.y,
      );
      final result = ghostty_grid_ref_row(gridRef, _outU64.cast());
      return (result, _outU64.value);
    });
  }

  @override
  CResult<Style> gridRefStyle(RawGridRef ref) {
    return using((arena) {
      final gridRef = GridRef.$allocate(
        arena,
        size: sizeOf<GridRef>(),
        node: Pointer<Void>.fromAddress(ref.node),
        x: ref.x,
        y: ref.y,
      );
      _outStyle.ref.size = sizeOf<native.Style>();
      final result = ghostty_grid_ref_style(gridRef, _outStyle);
      return (result, _readNativeStyle(_outStyle.ref));
    });
  }

  @override
  CResult<List<int>> gridRefGraphemes(RawGridRef ref) {
    return using((arena) {
      final outLen = arena<Size>();
      final gridRef = GridRef.$allocate(
        arena,
        size: sizeOf<GridRef>(),
        node: Pointer<Void>.fromAddress(ref.node),
        x: ref.x,
        y: ref.y,
      );
      var result = ghostty_grid_ref_graphemes(
        gridRef,
        _graphemeBuf,
        32,
        outLen,
      );
      var len = outLen.value;

      if (result == Result.outOfSpace) {
        final bigBuf = arena<Uint32>(len);
        result = ghostty_grid_ref_graphemes(gridRef, bigBuf, len, outLen);
        len = outLen.value;
        return (result, [for (var i = 0; i < len; i++) bigBuf[i]]);
      }

      return (result, [for (var i = 0; i < len; i++) _graphemeBuf[i]]);
    });
  }

  @override
  CResult<String> gridRefHyperlinkUri(RawGridRef ref) {
    return using((arena) {
      final outLen = arena<Size>();
      var buf = arena<Uint8>(256);
      final gridRef = GridRef.$allocate(
        arena,
        size: sizeOf<GridRef>(),
        node: Pointer<Void>.fromAddress(ref.node),
        x: ref.x,
        y: ref.y,
      );
      var result = ghostty_grid_ref_hyperlink_uri(gridRef, buf, 256, outLen);
      var len = outLen.value;

      if (result == Result.outOfSpace) {
        buf = arena<Uint8>(len);
        result = ghostty_grid_ref_hyperlink_uri(gridRef, buf, len, outLen);
        len = outLen.value;
      }

      if (len == 0) return (result, '');
      return (result, utf8.decode(buf.asTypedList(len)));
    });
  }

  @override
  void trackedGridRefFree(int ref) {
    ghostty_tracked_grid_ref_free(Pointer.fromAddress(ref));
  }

  @override
  bool trackedGridRefHasValue(int ref) {
    return ghostty_tracked_grid_ref_has_value(Pointer.fromAddress(ref));
  }

  @override
  CResult<Position> trackedGridRefPoint(int ref, PointTag pointTag) {
    return using((arena) {
      final out = arena<PointCoordinate>();
      final result = ghostty_tracked_grid_ref_point(
        Pointer.fromAddress(ref),
        pointTag,
        out,
      );
      return (result, Position(row: out.ref.y, col: out.ref.x));
    });
  }

  @override
  Result trackedGridRefSet(
    int ref,
    int terminal,
    PointTag pointTag,
    Position position,
  ) {
    return using((arena) {
      final point = arena<Point>();
      _writePoint(point.ref, pointTag, position);
      return ghostty_tracked_grid_ref_set(
        Pointer.fromAddress(ref),
        Pointer.fromAddress(terminal),
        point.ref,
      );
    });
  }

  @override
  CResult<RawGridRef> trackedGridRefSnapshot(int ref) {
    return using((arena) {
      final gridRef = arena<GridRef>();
      gridRef.ref.size = sizeOf<GridRef>();
      final result = ghostty_tracked_grid_ref_snapshot(
        Pointer.fromAddress(ref),
        gridRef,
      );
      return (result, _readGridRef(gridRef.ref));
    });
  }

  @override
  CResult<Position> terminalPointFromGridRef(
    int terminal,
    RawGridRef ref,
    PointTag pointTag,
  ) {
    return using((arena) {
      final out = arena<PointCoordinate>();
      final gridRef = GridRef.$allocate(
        arena,
        size: sizeOf<GridRef>(),
        node: Pointer<Void>.fromAddress(ref.node),
        x: ref.x,
        y: ref.y,
      );
      final result = ghostty_terminal_point_from_grid_ref(
        Pointer.fromAddress(terminal),
        gridRef,
        pointTag,
        out,
      );
      return (result, Position(row: out.ref.y, col: out.ref.x));
    });
  }

  @override
  CResult<RawSelection?> terminalGetSelection(int handle) {
    return using((arena) {
      final selection = arena<Selection>();
      selection.ref.size = sizeOf<Selection>();
      final result = ghostty_terminal_get(
        Pointer.fromAddress(handle),
        .selection,
        selection.cast(),
      );
      if (result != .success) return (result, null);
      return (result, _readSelection(selection.ref));
    });
  }

  @override
  Result terminalSetSelection(int handle, RawSelection? selection) {
    if (selection == null) {
      return ghostty_terminal_set(
        Pointer.fromAddress(handle),
        .selection,
        nullptr,
      );
    }
    return using((arena) {
      final sel = arena<Selection>();
      _writeSelection(sel.ref, selection);
      return ghostty_terminal_set(
        Pointer.fromAddress(handle),
        .selection,
        sel.cast(),
      );
    });
  }

  @override
  CResult<RawSelection?> terminalSelectAll(int terminal) {
    return using((arena) {
      final out = arena<Selection>();
      out.ref.size = sizeOf<Selection>();
      final result = ghostty_terminal_select_all(
        Pointer.fromAddress(terminal),
        out,
      );
      if (result != .success) return (result, null);
      return (result, _readSelection(out.ref));
    });
  }

  @override
  CResult<RawSelection?> terminalSelectWord(
    int terminal,
    RawGridRef ref, {
    List<int>? boundaryCodepoints,
  }) {
    return using((arena) {
      final opts = arena<TerminalSelectWordOptions>();
      final out = arena<Selection>();
      final codepoints = _writeCodepoints(arena, boundaryCodepoints);
      opts.ref
        ..size = sizeOf<TerminalSelectWordOptions>()
        ..boundary_codepoints = codepoints
        ..boundary_codepoints_len = boundaryCodepoints?.length ?? 0;
      _writeGridRef(opts.ref.ref, ref);
      out.ref.size = sizeOf<Selection>();
      final result = ghostty_terminal_select_word(
        Pointer.fromAddress(terminal),
        opts,
        out,
      );
      if (result != .success) return (result, null);
      return (result, _readSelection(out.ref));
    });
  }

  @override
  CResult<RawSelection?> terminalSelectWordBetween(
    int terminal,
    RawGridRef start,
    RawGridRef end, {
    List<int>? boundaryCodepoints,
  }) {
    return using((arena) {
      final opts = arena<TerminalSelectWordBetweenOptions>();
      final out = arena<Selection>();
      final codepoints = _writeCodepoints(arena, boundaryCodepoints);
      opts.ref
        ..size = sizeOf<TerminalSelectWordBetweenOptions>()
        ..boundary_codepoints = codepoints
        ..boundary_codepoints_len = boundaryCodepoints?.length ?? 0;
      _writeGridRef(opts.ref.start, start);
      _writeGridRef(opts.ref.end, end);
      out.ref.size = sizeOf<Selection>();
      final result = ghostty_terminal_select_word_between(
        Pointer.fromAddress(terminal),
        opts,
        out,
      );
      if (result != .success) return (result, null);
      return (result, _readSelection(out.ref));
    });
  }

  @override
  CResult<RawSelection?> terminalSelectLine(
    int terminal,
    RawGridRef ref, {
    List<int>? whitespace,
    bool semanticPromptBoundary = false,
  }) {
    return using((arena) {
      final opts = arena<TerminalSelectLineOptions>();
      final out = arena<Selection>();
      final codepoints = _writeCodepoints(arena, whitespace);
      opts.ref
        ..size = sizeOf<TerminalSelectLineOptions>()
        ..whitespace = codepoints
        ..whitespace_len = whitespace?.length ?? 0
        ..semantic_prompt_boundary = semanticPromptBoundary;
      _writeGridRef(opts.ref.ref, ref);
      out.ref.size = sizeOf<Selection>();
      final result = ghostty_terminal_select_line(
        Pointer.fromAddress(terminal),
        opts,
        out,
      );
      if (result != .success) return (result, null);
      return (result, _readSelection(out.ref));
    });
  }

  @override
  CResult<RawSelection?> terminalSelectOutput(int terminal, RawGridRef ref) {
    return using((arena) {
      final out = arena<Selection>();
      final gridRef = GridRef.$allocate(
        arena,
        size: sizeOf<GridRef>(),
        node: Pointer<Void>.fromAddress(ref.node),
        x: ref.x,
        y: ref.y,
      );
      out.ref.size = sizeOf<Selection>();
      final result = ghostty_terminal_select_output(
        Pointer.fromAddress(terminal),
        gridRef.ref,
        out,
      );
      if (result != .success) return (result, null);
      return (result, _readSelection(out.ref));
    });
  }

  @override
  CResult<RawSelection?> terminalSelectionAdjust(
    int terminal,
    RawSelection selection,
    SelectionAdjust adjustment,
  ) {
    return using((arena) {
      final sel = arena<Selection>();
      _writeSelection(sel.ref, selection);
      final result = ghostty_terminal_selection_adjust(
        Pointer.fromAddress(terminal),
        sel,
        adjustment,
      );
      if (result != .success) return (result, null);
      return (result, _readSelection(sel.ref));
    });
  }

  @override
  CResult<SelectionOrder> terminalSelectionOrder(
    int terminal,
    RawSelection selection,
  ) {
    return using((arena) {
      final sel = arena<Selection>();
      final out = arena<UnsignedInt>();
      _writeSelection(sel.ref, selection);
      final result = ghostty_terminal_selection_order(
        Pointer.fromAddress(terminal),
        sel,
        out.cast(),
      );
      if (result != .success) return (result, .forward);
      return (result, SelectionOrder.fromValue(out.value));
    });
  }

  @override
  CResult<RawSelection?> terminalSelectionOrdered(
    int terminal,
    RawSelection selection,
    SelectionOrder desired,
  ) {
    return using((arena) {
      final sel = arena<Selection>();
      final out = arena<Selection>();
      _writeSelection(sel.ref, selection);
      out.ref.size = sizeOf<Selection>();
      final result = ghostty_terminal_selection_ordered(
        Pointer.fromAddress(terminal),
        sel,
        desired,
        out,
      );
      if (result != .success) return (result, null);
      return (result, _readSelection(out.ref));
    });
  }

  @override
  CResult<bool> terminalSelectionContains(
    int terminal,
    RawSelection selection,
    PointTag pointTag,
    Position position,
  ) {
    return using((arena) {
      final sel = arena<Selection>();
      final point = arena<Point>();
      _writeSelection(sel.ref, selection);
      _writePoint(point.ref, pointTag, position);
      final result = ghostty_terminal_selection_contains(
        Pointer.fromAddress(terminal),
        sel,
        point.ref,
        _outBool,
      );
      return (result, _outBool.value);
    });
  }

  @override
  CResult<bool> terminalSelectionEqual(
    int terminal,
    RawSelection a,
    RawSelection b,
  ) {
    return using((arena) {
      final selA = arena<Selection>();
      final selB = arena<Selection>();
      _writeSelection(selA.ref, a);
      _writeSelection(selB.ref, b);
      final result = ghostty_terminal_selection_equal(
        Pointer.fromAddress(terminal),
        selA,
        selB,
        _outBool,
      );
      return (result, _outBool.value);
    });
  }

  @override
  CResult<String> terminalSelectionFormat(
    int terminal,
    FormatterFormat format, {
    bool unwrap = false,
    bool trim = false,
    RawSelection? selection,
  }) {
    return using((arena) {
      late final Pointer<Selection> selected;
      if (selection == null) {
        selected = nullptr;
      } else {
        selected = arena<Selection>();
        _writeSelection(selected.ref, selection);
      }
      final opts = TerminalSelectionFormatOptions.$allocate(
        arena,
        size: sizeOf<TerminalSelectionFormatOptions>(),
        emit: format,
        unwrap: unwrap,
        trim: trim,
        selection: selected,
      );
      var result = ghostty_terminal_selection_format_buf(
        Pointer.fromAddress(terminal),
        opts.ref,
        _formatBuffer,
        _formatBufferCapacity,
        _outSize,
      );
      if (result == .outOfSpace) {
        _growFormatBuffer(_outSize.value);
        result = ghostty_terminal_selection_format_buf(
          Pointer.fromAddress(terminal),
          opts.ref,
          _formatBuffer,
          _formatBufferCapacity,
          _outSize,
        );
      }
      final len = _outSize.value;
      if (result != .success || len == 0) return (result, '');
      return (result, utf8.decode(_formatBuffer.asTypedList(len)));
    });
  }

  @override
  CResult<int> selectionGestureNew() {
    return using((arena) {
      final out = arena<SelectionGesture>();
      final result = ghostty_selection_gesture_new(nullptr, out);
      return (result, out.value.address);
    });
  }

  @override
  void selectionGestureFree(int gesture, int terminal) {
    ghostty_selection_gesture_free(
      Pointer.fromAddress(gesture),
      Pointer.fromAddress(terminal),
    );
  }

  @override
  void selectionGestureReset(int gesture, int terminal) {
    ghostty_selection_gesture_reset(
      Pointer.fromAddress(gesture),
      Pointer.fromAddress(terminal),
    );
  }

  @override
  CResult<RawSelection?> selectionGestureEvent(
    int gesture,
    int terminal,
    int event,
  ) {
    return using((arena) {
      final out = arena<Selection>();
      out.ref.size = sizeOf<Selection>();
      final result = ghostty_selection_gesture_event(
        Pointer.fromAddress(gesture),
        Pointer.fromAddress(terminal),
        Pointer.fromAddress(event),
        out,
      );
      if (result != .success) return (result, null);
      return (result, _readSelection(out.ref));
    });
  }

  @override
  CResult<int> selectionGestureEventNew(SelectionGestureEventType type) {
    return using((arena) {
      final out = arena<SelectionGestureEvent>();
      final result = ghostty_selection_gesture_event_new(nullptr, out, type);
      return (result, out.value.address);
    });
  }

  @override
  void selectionGestureEventFree(int event) {
    ghostty_selection_gesture_event_free(Pointer.fromAddress(event));
  }

  @override
  Result selectionGestureEventClear(
    int event,
    SelectionGestureEventOption option,
  ) {
    return ghostty_selection_gesture_event_set(
      Pointer.fromAddress(event),
      option,
      nullptr,
    );
  }

  @override
  Result selectionGestureEventSetRef(int event, RawGridRef ref) {
    return using((arena) {
      final value = GridRef.$allocate(
        arena,
        size: sizeOf<GridRef>(),
        node: Pointer<Void>.fromAddress(ref.node),
        x: ref.x,
        y: ref.y,
      );
      return ghostty_selection_gesture_event_set(
        Pointer.fromAddress(event),
        .ref,
        value.cast(),
      );
    });
  }

  @override
  Result selectionGestureEventSetPosition(int event, double x, double y) {
    return using((arena) {
      final value = SurfacePosition.$allocate(arena, x: x, y: y);
      return ghostty_selection_gesture_event_set(
        Pointer.fromAddress(event),
        .position,
        value.cast(),
      );
    });
  }

  @override
  Result selectionGestureEventSetRepeatDistance(int event, double value) {
    return using((arena) {
      final ptr = arena<Double>();
      ptr.value = value;
      return ghostty_selection_gesture_event_set(
        Pointer.fromAddress(event),
        .repeatDistance,
        ptr.cast(),
      );
    });
  }

  @override
  Result selectionGestureEventSetTimeNs(int event, int value) {
    return using((arena) {
      final ptr = arena<Uint64>();
      ptr.value = value;
      return ghostty_selection_gesture_event_set(
        Pointer.fromAddress(event),
        .timeNs,
        ptr.cast(),
      );
    });
  }

  @override
  Result selectionGestureEventSetRepeatIntervalNs(int event, int value) {
    return using((arena) {
      final ptr = arena<Uint64>();
      ptr.value = value;
      return ghostty_selection_gesture_event_set(
        Pointer.fromAddress(event),
        .repeatIntervalNs,
        ptr.cast(),
      );
    });
  }

  @override
  Result selectionGestureEventSetWordBoundaryCodepoints(
    int event,
    List<int> codepoints,
  ) {
    return using((arena) {
      final ptr = Codepoints.$allocate(
        arena,
        ptr: _writeCodepoints(arena, codepoints),
        len: codepoints.length,
      );
      return ghostty_selection_gesture_event_set(
        Pointer.fromAddress(event),
        .wordBoundaryCodepoints,
        ptr.cast(),
      );
    });
  }

  @override
  Result selectionGestureEventSetBehaviors(
    int event,
    SelectionGestureBehavior singleClick,
    SelectionGestureBehavior doubleClick,
    SelectionGestureBehavior tripleClick,
  ) {
    return using((arena) {
      final ptr = SelectionGestureBehaviors.$allocate(
        arena,
        single_click: singleClick,
        double_click: doubleClick,
        triple_click: tripleClick,
      );
      return ghostty_selection_gesture_event_set(
        Pointer.fromAddress(event),
        .behaviors,
        ptr.cast(),
      );
    });
  }

  @override
  Result selectionGestureEventSetRectangle(int event, {required bool value}) {
    return using((arena) {
      final ptr = arena<Bool>();
      ptr.value = value;
      return ghostty_selection_gesture_event_set(
        Pointer.fromAddress(event),
        .rectangle,
        ptr.cast(),
      );
    });
  }

  @override
  Result selectionGestureEventSetGeometry(
    int event, {
    required int columns,
    required int cellWidth,
    required int paddingLeft,
    required int screenHeight,
  }) {
    return using((arena) {
      final ptr = SelectionGestureGeometry.$allocate(
        arena,
        columns: columns,
        cell_width: cellWidth,
        padding_left: paddingLeft,
        screen_height: screenHeight,
      );
      return ghostty_selection_gesture_event_set(
        Pointer.fromAddress(event),
        .geometry,
        ptr.cast(),
      );
    });
  }

  @override
  Result selectionGestureEventSetViewport(
    int event, {
    required Position position,
  }) {
    return using((arena) {
      final ptr = PointCoordinate.$allocate(
        arena,
        x: position.col,
        y: position.row,
      );
      return ghostty_selection_gesture_event_set(
        Pointer.fromAddress(event),
        .viewport,
        ptr.cast(),
      );
    });
  }

  @override
  CResult<int> selectionGestureGetClickCount(int gesture, int terminal) {
    return using((arena) {
      final out = arena<Uint8>();
      final result = ghostty_selection_gesture_get(
        Pointer.fromAddress(gesture),
        Pointer.fromAddress(terminal),
        .clickCount,
        out.cast(),
      );
      return (result, out.value);
    });
  }

  @override
  CResult<bool> selectionGestureGetDragged(int gesture, int terminal) {
    return using((arena) {
      final out = arena<Bool>();
      final result = ghostty_selection_gesture_get(
        Pointer.fromAddress(gesture),
        Pointer.fromAddress(terminal),
        .dragged,
        out.cast(),
      );
      return (result, out.value);
    });
  }

  @override
  CResult<SelectionGestureAutoscroll> selectionGestureGetAutoscroll(
    int gesture,
    int terminal,
  ) {
    return using((arena) {
      final out = arena<UnsignedInt>();
      final result = ghostty_selection_gesture_get(
        Pointer.fromAddress(gesture),
        Pointer.fromAddress(terminal),
        .autoscroll,
        out.cast(),
      );
      if (result != .success) return (result, .none);
      return (result, SelectionGestureAutoscroll.fromValue(out.value));
    });
  }

  @override
  CResult<SelectionGestureBehavior> selectionGestureGetBehavior(
    int gesture,
    int terminal,
  ) {
    return using((arena) {
      final out = arena<UnsignedInt>();
      final result = ghostty_selection_gesture_get(
        Pointer.fromAddress(gesture),
        Pointer.fromAddress(terminal),
        .behavior,
        out.cast(),
      );
      if (result != .success) return (result, .cell);
      return (result, SelectionGestureBehavior.fromValue(out.value));
    });
  }

  @override
  CResult<RawGridRef> selectionGestureGetAnchor(int gesture, int terminal) {
    return using((arena) {
      final out = arena<GridRef>();
      out.ref.size = sizeOf<GridRef>();
      final result = ghostty_selection_gesture_get(
        Pointer.fromAddress(gesture),
        Pointer.fromAddress(terminal),
        .anchor,
        out.cast(),
      );
      if (result != .success) return (result, _emptyGridRef);
      return (result, _readGridRef(out.ref));
    });
  }

  @override
  CResult<RawSelectionGestureState> selectionGestureGetState(
    int gesture,
    int terminal,
  ) {
    const keys = _selectionGestureStateKeys;
    for (var i = 0; i < keys.length; i++) {
      _multiKeys[i] = keys[i].value;
      _multiValues[i] = (_multiOut + i).cast();
    }
    _multiGridRef.ref.size = sizeOf<GridRef>();
    _multiValues[4] = _multiGridRef.cast();
    final result = ghostty_selection_gesture_get_multi(
      Pointer.fromAddress(gesture),
      Pointer.fromAddress(terminal),
      keys.length,
      _multiKeys,
      _multiValues,
      _outSize,
    );
    final anchorAbsent = result == .noValue && _outSize.value == 4;
    if (result != .success && !anchorAbsent) {
      return (result, _emptySelectionGestureState);
    }
    return (
      anchorAbsent ? .success : result,
      (
        clickCount: (_multiOut + 0).cast<Uint8>().value,
        dragged: (_multiOut + 1).cast<Bool>().value,
        autoscroll: .fromValue((_multiOut + 2).cast<Int32>().value),
        behavior: .fromValue((_multiOut + 3).cast<Int32>().value),
        anchor: anchorAbsent ? null : _readGridRef(_multiGridRef.ref),
      ),
    );
  }

  @override
  CResult<int> formatterTerminalNew(
    int terminal,
    FormatterFormat format, {
    bool unwrap = false,
    bool trim = false,
    FormatterExtra extra = const FormatterExtra(),
    RawSelection? selection,
  }) {
    return using((arena) {
      final ptr = arena<Pointer<FormatterImpl>>();
      final opts = arena<FormatterTerminalOptions>();
      opts.ref
        ..size = sizeOf<FormatterTerminalOptions>()
        ..emitAsInt = format.value
        ..unwrap = unwrap
        ..trim = trim;

      opts.ref.extra
        ..size = sizeOf<FormatterTerminalExtra>()
        ..palette = extra.palette
        ..modes = extra.modes
        ..scrolling_region = extra.scrollingRegion
        ..tabstops = extra.tabstops
        ..pwd = extra.pwd
        ..keyboard = extra.keyboard;

      opts.ref.extra.screen
        ..size = sizeOf<FormatterScreenExtra>()
        ..cursor = extra.cursor
        ..style = extra.style
        ..hyperlink = extra.hyperlink
        ..protection = extra.protection
        ..kitty_keyboard = extra.kittyKeyboard
        ..charsets = extra.charsets;

      if (selection != null) {
        final sel = arena<Selection>();
        sel.ref.size = sizeOf<Selection>();
        _writeGridRef(sel.ref.start, selection.start);
        _writeGridRef(sel.ref.end, selection.end);
        sel.ref.rectangle = selection.rectangle;
        opts.ref.selection = sel;
      } else {
        opts.ref.selection = nullptr;
      }

      final result = ghostty_formatter_terminal_new(
        nullptr,
        ptr.cast(),
        Pointer.fromAddress(terminal),
        opts.ref,
      );
      return (result, ptr.value.address);
    });
  }

  @override
  void formatterFree(int formatter) {
    ghostty_formatter_free(Pointer.fromAddress(formatter));
  }

  @override
  CResult<String> formatterFormat(int formatter) {
    var result = ghostty_formatter_format_buf(
      Pointer.fromAddress(formatter),
      _formatBuffer,
      _formatBufferCapacity,
      _outSize,
    );
    if (result == .outOfSpace) {
      _growFormatBuffer(_outSize.value);
      result = ghostty_formatter_format_buf(
        Pointer.fromAddress(formatter),
        _formatBuffer,
        _formatBufferCapacity,
        _outSize,
      );
    }
    final len = _outSize.value;
    if (result != .success || len == 0) return (result, '');
    return (result, utf8.decode(_formatBuffer.asTypedList(len)));
  }

  @override
  void terminalSetOnWritePty(int handle, ValueSetter<Uint8List>? callback) {
    final map = _callables.putIfAbsent(handle, () => {});
    map[TerminalOption.writePty]?.close();

    if (callback == null) {
      map.remove(TerminalOption.writePty);
      ghostty_terminal_set(
        Pointer.fromAddress(handle),
        TerminalOption.writePty,
        nullptr,
      );
      return;
    }

    final callable =
        NativeCallable<
          Void Function(Terminal, Pointer<Void>, Pointer<Uint8>, Size)
        >.isolateLocal((
          Terminal terminal,
          Pointer<Void> userdata,
          Pointer<Uint8> data,
          int len,
        ) {
          try {
            callback(Uint8List.fromList(data.asTypedList(len)));
          } on Object catch (error, stackTrace) {
            _captureCallbackError(error, stackTrace);
          }
        });
    map[TerminalOption.writePty] = callable;
    ghostty_terminal_set(
      Pointer.fromAddress(handle),
      TerminalOption.writePty,
      callable.nativeFunction.cast(),
    );
  }

  @override
  void terminalSetOnBell(int handle, VoidCallback? callback) {
    final map = _callables.putIfAbsent(handle, () => {});
    map[TerminalOption.bell]?.close();

    if (callback == null) {
      map.remove(TerminalOption.bell);
      ghostty_terminal_set(
        Pointer.fromAddress(handle),
        TerminalOption.bell,
        nullptr,
      );
      return;
    }

    final callable =
        NativeCallable<Void Function(Terminal, Pointer<Void>)>.isolateLocal((
          Terminal terminal,
          Pointer<Void> userdata,
        ) {
          try {
            callback();
          } on Object catch (error, stackTrace) {
            _captureCallbackError(error, stackTrace);
          }
        });
    map[TerminalOption.bell] = callable;
    ghostty_terminal_set(
      Pointer.fromAddress(handle),
      TerminalOption.bell,
      callable.nativeFunction.cast(),
    );
  }

  @override
  void terminalSetOnClipboardWrite(
    int handle,
    ClipboardWriteCallback? callback,
  ) {
    final map = _callables.putIfAbsent(handle, () => {});
    const option = TerminalOption.clipboardWrite;
    map[option]?.close();

    if (callback == null) {
      map.remove(option);
      ghostty_terminal_set(Pointer.fromAddress(handle), option, nullptr);
      return;
    }

    final callable =
        NativeCallable<
          UnsignedInt Function(
            Terminal,
            Pointer<Void>,
            Pointer<native.ClipboardWrite>,
          )
        >.isolateLocal((
          Terminal terminal,
          Pointer<Void> userdata,
          Pointer<native.ClipboardWrite> write,
        ) {
          try {
            final request = write.ref;
            final contents = <ClipboardContent>[
              for (var i = 0; i < request.contents_len; i++)
                (
                  mime: utf8.decode(
                    request.contents[i].mime.ptr.asTypedList(
                      request.contents[i].mime.len,
                    ),
                  ),
                  data: Uint8List.fromList(
                    request.contents[i].data.ptr.asTypedList(
                      request.contents[i].data.len,
                    ),
                  ),
                ),
            ];
            return callback((
              location: request.location,
              contents: List.unmodifiable(contents),
            )).value;
          } on Object catch (error, stackTrace) {
            _captureCallbackError(error, stackTrace);
            return ClipboardWriteResult.ioError.value;
          }
        }, exceptionalReturn: _clipboardWriteExceptionResult);
    map[option] = callable;
    ghostty_terminal_set(
      Pointer.fromAddress(handle),
      option,
      callable.nativeFunction.cast(),
    );
  }

  @override
  void terminalSetOnDesktopNotification(
    int handle,
    DesktopNotificationCallback? callback,
  ) {
    final map = _callables.putIfAbsent(handle, () => {});
    const option = TerminalOption.desktopNotification;
    map[option]?.close();
    if (callback == null) {
      map.remove(option);
      ghostty_terminal_set(Pointer.fromAddress(handle), option, nullptr);
      return;
    }
    final callable =
        NativeCallable<
          Void Function(
            Terminal,
            Pointer<Void>,
            Pointer<TerminalDesktopNotification>,
          )
        >.isolateLocal((
          Terminal terminal,
          Pointer<Void> userdata,
          Pointer<TerminalDesktopNotification> notification,
        ) {
          try {
            final value = notification.ref;
            if (value.size < sizeOf<TerminalDesktopNotification>()) return;
            callback((
              title: utf8.decode(value.title.ptr.asTypedList(value.title.len)),
              body: utf8.decode(value.body.ptr.asTypedList(value.body.len)),
            ));
          } on Object catch (error, stackTrace) {
            _captureCallbackError(error, stackTrace);
          }
        });
    map[option] = callable;
    ghostty_terminal_set(
      Pointer.fromAddress(handle),
      option,
      callable.nativeFunction.cast(),
    );
  }

  @override
  void terminalSetOnProgressReport(
    int handle,
    TerminalProgressCallback? callback,
  ) {
    final map = _callables.putIfAbsent(handle, () => {});
    const option = TerminalOption.progressReport;
    map[option]?.close();
    if (callback == null) {
      map.remove(option);
      ghostty_terminal_set(Pointer.fromAddress(handle), option, nullptr);
      return;
    }
    final callable =
        NativeCallable<
          Void Function(
            Terminal,
            Pointer<Void>,
            Pointer<TerminalProgressReport>,
          )
        >.isolateLocal((
          Terminal terminal,
          Pointer<Void> userdata,
          Pointer<TerminalProgressReport> report,
        ) {
          try {
            final value = report.ref;
            if (value.size < sizeOf<TerminalProgressReport>()) return;
            final progress = value.progress;
            callback((
              state: value.state,
              progress: progress < 0 ? null : progress,
            ));
          } on Object catch (error, stackTrace) {
            _captureCallbackError(error, stackTrace);
          }
        });
    map[option] = callable;
    ghostty_terminal_set(
      Pointer.fromAddress(handle),
      option,
      callable.nativeFunction.cast(),
    );
  }

  @override
  void terminalSetOnTitleChanged(int handle, VoidCallback? callback) {
    final map = _callables.putIfAbsent(handle, () => {});
    map[TerminalOption.titleChanged]?.close();

    if (callback == null) {
      map.remove(TerminalOption.titleChanged);
      ghostty_terminal_set(
        Pointer.fromAddress(handle),
        TerminalOption.titleChanged,
        nullptr,
      );
      return;
    }

    final callable =
        NativeCallable<Void Function(Terminal, Pointer<Void>)>.isolateLocal((
          Terminal terminal,
          Pointer<Void> userdata,
        ) {
          try {
            callback();
          } on Object catch (error, stackTrace) {
            _captureCallbackError(error, stackTrace);
          }
        });
    map[TerminalOption.titleChanged] = callable;
    ghostty_terminal_set(
      Pointer.fromAddress(handle),
      TerminalOption.titleChanged,
      callable.nativeFunction.cast(),
    );
  }

  @override
  void terminalSetOnPwdChanged(int handle, VoidCallback? callback) {
    final map = _callables.putIfAbsent(handle, () => {});
    map[TerminalOption.pwdChanged]?.close();

    if (callback == null) {
      map.remove(TerminalOption.pwdChanged);
      ghostty_terminal_set(
        Pointer.fromAddress(handle),
        TerminalOption.pwdChanged,
        nullptr,
      );
      return;
    }

    final callable =
        NativeCallable<Void Function(Terminal, Pointer<Void>)>.isolateLocal((
          Terminal terminal,
          Pointer<Void> userdata,
        ) {
          try {
            callback();
          } on Object catch (error, stackTrace) {
            _captureCallbackError(error, stackTrace);
          }
        });
    map[TerminalOption.pwdChanged] = callable;
    ghostty_terminal_set(
      Pointer.fromAddress(handle),
      TerminalOption.pwdChanged,
      callable.nativeFunction.cast(),
    );
  }

  @override
  void terminalSetOnEnquiry(int handle, ValueGetter<Uint8List>? callback) {
    final map = _callables.putIfAbsent(handle, () => {});
    map[TerminalOption.enquiry]?.close();

    if (callback == null) {
      map.remove(TerminalOption.enquiry);
      ghostty_terminal_set(
        Pointer.fromAddress(handle),
        TerminalOption.enquiry,
        nullptr,
      );
      return;
    }

    final bufMap = _stringBuffers.putIfAbsent(handle, () => {});
    final strPtr =
        bufMap[TerminalOption.enquiry]?.str ??
        native.String.$allocate(calloc, ptr: nullptr.cast(), len: 0);
    bufMap[TerminalOption.enquiry] = (
      str: strPtr,
      data: bufMap[TerminalOption.enquiry]?.data ?? nullptr.cast<Uint8>(),
    );

    final callable =
        NativeCallable<
          native.String Function(Terminal, Pointer<Void>)
        >.isolateLocal((Terminal terminal, Pointer<Void> userdata) {
          try {
            final bytes = callback();
            final current = bufMap[TerminalOption.enquiry]!;
            if (current.data != nullptr) calloc.free(current.data);
            final dataPtr = calloc<Uint8>(bytes.length);
            dataPtr.asTypedList(bytes.length).setAll(0, bytes);
            bufMap[TerminalOption.enquiry] = (str: strPtr, data: dataPtr);
            strPtr.ref.ptr = dataPtr;
            strPtr.ref.len = bytes.length;
            return strPtr.ref;
          } on Object catch (error, stackTrace) {
            _captureCallbackError(error, stackTrace);
            strPtr.ref.ptr = nullptr;
            strPtr.ref.len = 0;
            return strPtr.ref;
          }
        });
    map[TerminalOption.enquiry] = callable;
    ghostty_terminal_set(
      Pointer.fromAddress(handle),
      TerminalOption.enquiry,
      callable.nativeFunction.cast(),
    );
  }

  @override
  void terminalSetOnXtversion(int handle, ValueGetter<String>? callback) {
    final map = _callables.putIfAbsent(handle, () => {});
    map[TerminalOption.xtversion]?.close();

    if (callback == null) {
      map.remove(TerminalOption.xtversion);
      ghostty_terminal_set(
        Pointer.fromAddress(handle),
        TerminalOption.xtversion,
        nullptr,
      );
      return;
    }

    final bufMap = _stringBuffers.putIfAbsent(handle, () => {});
    final strPtr =
        bufMap[TerminalOption.xtversion]?.str ??
        native.String.$allocate(calloc, ptr: nullptr.cast(), len: 0);
    bufMap[TerminalOption.xtversion] = (
      str: strPtr,
      data: bufMap[TerminalOption.xtversion]?.data ?? nullptr.cast<Uint8>(),
    );

    final callable =
        NativeCallable<
          native.String Function(Terminal, Pointer<Void>)
        >.isolateLocal((Terminal terminal, Pointer<Void> userdata) {
          try {
            final result = callback();
            final bytes = utf8.encode(result);
            final current = bufMap[TerminalOption.xtversion]!;
            if (current.data != nullptr) calloc.free(current.data);
            final dataPtr = calloc<Uint8>(bytes.length);
            dataPtr.asTypedList(bytes.length).setAll(0, bytes);
            bufMap[TerminalOption.xtversion] = (str: strPtr, data: dataPtr);
            strPtr.ref.ptr = dataPtr;
            strPtr.ref.len = bytes.length;
            return strPtr.ref;
          } on Object catch (error, stackTrace) {
            _captureCallbackError(error, stackTrace);
            strPtr.ref.ptr = nullptr;
            strPtr.ref.len = 0;
            return strPtr.ref;
          }
        });
    map[TerminalOption.xtversion] = callable;
    ghostty_terminal_set(
      Pointer.fromAddress(handle),
      TerminalOption.xtversion,
      callable.nativeFunction.cast(),
    );
  }

  @override
  void terminalSetOnColorScheme(
    int handle,
    ValueGetter<ColorScheme?>? callback,
  ) {
    final map = _callables.putIfAbsent(handle, () => {});
    map[TerminalOption.colorScheme]?.close();

    if (callback == null) {
      map.remove(TerminalOption.colorScheme);
      ghostty_terminal_set(
        Pointer.fromAddress(handle),
        TerminalOption.colorScheme,
        nullptr,
      );
      return;
    }

    final callable =
        NativeCallable<
          Bool Function(Terminal, Pointer<Void>, Pointer<UnsignedInt>)
        >.isolateLocal((
          Terminal terminal,
          Pointer<Void> userdata,
          Pointer<UnsignedInt> outScheme,
        ) {
          try {
            final result = callback();
            if (result == null) return false;
            outScheme.value = result.value;
            return true;
          } on Object catch (error, stackTrace) {
            _captureCallbackError(error, stackTrace);
            return false;
          }
        }, exceptionalReturn: false);
    map[TerminalOption.colorScheme] = callable;
    ghostty_terminal_set(
      Pointer.fromAddress(handle),
      TerminalOption.colorScheme,
      callable.nativeFunction.cast(),
    );
  }

  @override
  void terminalSetOnSize(int handle, ValueGetter<TerminalSizeInfo?>? callback) {
    final map = _callables.putIfAbsent(handle, () => {});
    map[TerminalOption.size]?.close();

    if (callback == null) {
      map.remove(TerminalOption.size);
      ghostty_terminal_set(
        Pointer.fromAddress(handle),
        TerminalOption.size,
        nullptr,
      );
      return;
    }

    final callable =
        NativeCallable<
          Bool Function(Terminal, Pointer<Void>, Pointer<SizeReportSize>)
        >.isolateLocal((
          Terminal terminal,
          Pointer<Void> userdata,
          Pointer<SizeReportSize> outSize,
        ) {
          try {
            final result = callback();
            if (result == null) return false;
            outSize.ref.rows = result.rows;
            outSize.ref.columns = result.columns;
            outSize.ref.cell_width = result.cellWidth;
            outSize.ref.cell_height = result.cellHeight;
            return true;
          } on Object catch (error, stackTrace) {
            _captureCallbackError(error, stackTrace);
            return false;
          }
        }, exceptionalReturn: false);
    map[TerminalOption.size] = callable;
    ghostty_terminal_set(
      Pointer.fromAddress(handle),
      TerminalOption.size,
      callable.nativeFunction.cast(),
    );
  }

  @override
  void terminalSetOnDeviceAttributes(
    int handle,
    ValueGetter<DeviceAttributesResponse?>? callback,
  ) {
    final map = _callables.putIfAbsent(handle, () => {});
    map[TerminalOption.deviceAttributes]?.close();

    if (callback == null) {
      map.remove(TerminalOption.deviceAttributes);
      ghostty_terminal_set(
        Pointer.fromAddress(handle),
        TerminalOption.deviceAttributes,
        nullptr,
      );
      return;
    }

    final callable =
        NativeCallable<
          Bool Function(Terminal, Pointer<Void>, Pointer<DeviceAttributes>)
        >.isolateLocal((
          Terminal terminal,
          Pointer<Void> userdata,
          Pointer<DeviceAttributes> outAttrs,
        ) {
          try {
            final result = callback();
            if (result == null) return false;
            outAttrs.ref.primary.conformance_level =
                result.primary.conformanceLevel;
            final featureCount = result.primary.features.length > 64
                ? 64
                : result.primary.features.length;
            for (var i = 0; i < featureCount; i++) {
              outAttrs.ref.primary.features[i] = result.primary.features[i];
            }
            outAttrs.ref.primary.num_features = featureCount;
            outAttrs.ref.secondary.device_type = result.secondary.deviceType;
            outAttrs.ref.secondary.firmware_version =
                result.secondary.firmwareVersion;
            outAttrs.ref.secondary.rom_cartridge =
                result.secondary.romCartridge;
            outAttrs.ref.tertiary.unit_id = result.tertiary.unitId;
            return true;
          } on Object catch (error, stackTrace) {
            _captureCallbackError(error, stackTrace);
            return false;
          }
        }, exceptionalReturn: false);
    map[TerminalOption.deviceAttributes] = callable;
    ghostty_terminal_set(
      Pointer.fromAddress(handle),
      TerminalOption.deviceAttributes,
      callable.nativeFunction.cast(),
    );
  }

  @override
  void terminalDisposeCallbacks(int handle) {
    if (_callables.remove(handle) case Map(:final keys, :final values)) {
      for (final option in keys) {
        ghostty_terminal_set(Pointer.fromAddress(handle), option, nullptr);
      }
      for (final c in values) {
        c.close();
      }
    }

    if (_stringBuffers.remove(handle) case Map(:final values)) {
      for (final buf in values) {
        if (buf.data != nullptr) calloc.free(buf.data);
        calloc.free(buf.str);
      }
    }
  }

  @override
  void sysSetLogCallback(SysLogCallback callback) {
    _installSysLog((userdata, level, scope, scopeLen, msg, msgLen) {
      try {
        callback(
          SysLogLevel.fromValue(level),
          utf8.decode(scope.asTypedList(scopeLen), allowMalformed: true),
          utf8.decode(msg.asTypedList(msgLen), allowMalformed: true),
        );
      } on Object catch (_) {}
    });
  }

  @override
  void sysSetLogToStderr() {
    _installSysLog((userdata, level, scope, scopeLen, msg, msgLen) {
      ghostty_sys_log_stderr(
        userdata,
        SysLogLevel.fromValue(level),
        scope,
        scopeLen,
        msg,
        msgLen,
      );
    });
  }

  @override
  void sysClearLogCallback() {
    ghostty_sys_set(SysOption.log, nullptr);
    _sysLogCallable?.close();
    _sysLogCallable = null;
  }

  @override
  void sysSetPngDecoder(PngDecoder decoder) {
    _sysDecodePngCallable?.close();
    final callable =
        NativeCallable<
          Bool Function(
            Pointer<Void>,
            Pointer<Allocator>,
            Pointer<Uint8>,
            Size,
            Pointer<SysImage>,
          )
        >.isolateLocal((
          Pointer<Void> userdata,
          Pointer<Allocator> allocator,
          Pointer<Uint8> pngData,
          int pngLen,
          Pointer<SysImage> out,
        ) {
          try {
            final bytes = Uint8List.fromList(pngData.asTypedList(pngLen));
            final decoded = decoder(bytes);
            if (decoded == null) return false;
            final rgba = decoded.rgba;
            final buf = ghostty_alloc(allocator, rgba.length);
            if (buf == nullptr) return false;
            buf.asTypedList(rgba.length).setAll(0, rgba);
            out.ref.width = decoded.width;
            out.ref.height = decoded.height;
            out.ref.data = buf;
            out.ref.data_len = rgba.length;
            return true;
          } on Object catch (_) {
            return false;
          }
        }, exceptionalReturn: false);
    _sysDecodePngCallable = callable;
    ghostty_sys_set(SysOption.decodePng, callable.nativeFunction.cast());
  }

  @override
  void sysClearPngDecoder() {
    ghostty_sys_set(SysOption.decodePng, nullptr);
    _sysDecodePngCallable?.close();
    _sysDecodePngCallable = null;
  }

  @override
  int kittyGraphicsGet(int handle) {
    final outPtr = _outOpaque;
    final code = ghostty_terminal_get(
      Pointer.fromAddress(handle),
      TerminalData.kittyGraphics,
      outPtr.cast(),
    );
    if (code != Result.success) return 0;
    return outPtr.value.address;
  }

  @override
  int kittyGraphicsImage(int graphics, int imageId) {
    if (graphics == 0) return 0;
    final image = ghostty_kitty_graphics_image(
      Pointer.fromAddress(graphics),
      imageId,
    );
    return image.address;
  }

  @override
  CResult<int> kittyGraphicsImageGetId(int image) =>
      _kittyImageGetU32(image, KittyGraphicsImageData.id);

  @override
  CResult<int> kittyGraphicsImageGetNumber(int image) =>
      _kittyImageGetU32(image, KittyGraphicsImageData.number);

  @override
  CResult<int> kittyGraphicsImageGetWidth(int image) =>
      _kittyImageGetU32(image, KittyGraphicsImageData.width);

  @override
  CResult<int> kittyGraphicsImageGetHeight(int image) =>
      _kittyImageGetU32(image, KittyGraphicsImageData.height);

  @override
  CResult<KittyImageFormat> kittyGraphicsImageGetFormat(int image) {
    final (code, value) = _kittyImageGetU32(
      image,
      KittyGraphicsImageData.format,
    );
    return (code, KittyImageFormat.fromValue(value));
  }

  @override
  CResult<KittyImageCompression> kittyGraphicsImageGetCompression(int image) {
    final (code, value) = _kittyImageGetU32(
      image,
      KittyGraphicsImageData.compression,
    );
    return (code, KittyImageCompression.fromValue(value));
  }

  @override
  CResult<int> kittyGraphicsImageGetGeneration(int image) {
    return _kittyImageGetU64(image, KittyGraphicsImageData.generation);
  }

  @override
  CResult<int> kittyGraphicsGetGeneration(int graphics) {
    if (graphics == 0) return (Result.invalidValue, 0);
    final code = ghostty_kitty_graphics_get(
      Pointer.fromAddress(graphics),
      KittyGraphicsData.generation,
      _outU64.cast(),
    );
    return (code, _outU64.value);
  }

  @override
  CResult<Uint8List> kittyGraphicsImageGetPixelData(int image) {
    if (image == 0) return (Result.invalidValue, Uint8List(0));
    const keys = _kittyImagePixelDataKeys;
    for (var i = 0; i < keys.length; i++) {
      _multiKeys[i] = keys[i].value;
      _multiValues[i] = (_multiOut + i).cast();
    }
    final result = ghostty_kitty_graphics_image_get_multi(
      Pointer.fromAddress(image),
      keys.length,
      _multiKeys,
      _multiValues,
      _outSize,
    );
    if (result != .success) return (result, Uint8List(0));
    final ptr = (_multiOut + 0).cast<Pointer<Uint8>>().value;
    final len = (_multiOut + 1).cast<Size>().value;
    if (ptr == nullptr || len == 0) return (Result.success, Uint8List(0));
    return (Result.success, Uint8List.fromList(ptr.asTypedList(len)));
  }

  CResult<int> _kittyImageGetU32(int image, KittyGraphicsImageData data) {
    if (image == 0) return (Result.invalidValue, 0);
    final code = ghostty_kitty_graphics_image_get(
      Pointer.fromAddress(image),
      data,
      _outU32.cast(),
    );
    return (code, _outU32.value);
  }

  CResult<int> _kittyImageGetU64(int image, KittyGraphicsImageData data) {
    if (image == 0) return (Result.invalidValue, 0);
    final code = ghostty_kitty_graphics_image_get(
      Pointer.fromAddress(image),
      data,
      _outU64.cast(),
    );
    return (code, _outU64.value);
  }

  @override
  CResult<int> kittyGraphicsPlacementIteratorNew() {
    final out = calloc<KittyGraphicsPlacementIterator>();
    final code = ghostty_kitty_graphics_placement_iterator_new(nullptr, out);
    final handle = out.value.address;
    calloc.free(out);
    return (code, handle);
  }

  @override
  void kittyGraphicsPlacementIteratorFree(int iterator) {
    if (iterator == 0) return;
    ghostty_kitty_graphics_placement_iterator_free(
      Pointer<KittyGraphicsPlacementIteratorImpl>.fromAddress(iterator),
    );
  }

  @override
  Result kittyGraphicsGetPlacements(int graphics, int iterator) {
    if (graphics == 0 || iterator == 0) return Result.invalidValue;
    final out = calloc<KittyGraphicsPlacementIterator>();
    out.value = Pointer<KittyGraphicsPlacementIteratorImpl>.fromAddress(
      iterator,
    );
    final code = ghostty_kitty_graphics_get(
      Pointer.fromAddress(graphics),
      KittyGraphicsData.placementIterator,
      out.cast(),
    );
    calloc.free(out);
    return code;
  }

  @override
  Result kittyGraphicsPlacementIteratorSetLayer(
    int iterator,
    KittyPlacementLayer layer,
  ) {
    if (iterator == 0) return Result.invalidValue;
    final layerPtr = calloc<UnsignedInt>()..value = layer.value;
    final code = ghostty_kitty_graphics_placement_iterator_set(
      Pointer<KittyGraphicsPlacementIteratorImpl>.fromAddress(iterator),
      KittyGraphicsPlacementIteratorOption.layer,
      layerPtr.cast(),
    );
    calloc.free(layerPtr);
    return code;
  }

  @override
  bool kittyGraphicsPlacementNext(int iterator) {
    if (iterator == 0) return false;
    return ghostty_kitty_graphics_placement_next(
      Pointer<KittyGraphicsPlacementIteratorImpl>.fromAddress(iterator),
    );
  }

  @override
  CResult<RawPlacement> kittyGraphicsPlacementGet(int iterator) {
    if (iterator == 0) return (Result.invalidValue, _emptyPlacement);
    const keys = _kittyPlacementKeys;
    for (var i = 0; i < keys.length; i++) {
      _multiKeys[i] = keys[i].value;
      _multiValues[i] = (_multiOut + i).cast();
    }
    final result = ghostty_kitty_graphics_placement_get_multi(
      Pointer.fromAddress(iterator),
      keys.length,
      _multiKeys,
      _multiValues,
      _outSize,
    );
    if (result != .success) return (result, _emptyPlacement);
    return (
      result,
      (
        imageId: (_multiOut + 0).cast<Uint32>().value,
        placementId: (_multiOut + 1).cast<Uint32>().value,
        isVirtual: (_multiOut + 2).cast<Bool>().value,
        xOffset: (_multiOut + 3).cast<Uint32>().value,
        yOffset: (_multiOut + 4).cast<Uint32>().value,
        sourceX: (_multiOut + 5).cast<Uint32>().value,
        sourceY: (_multiOut + 6).cast<Uint32>().value,
        sourceWidth: (_multiOut + 7).cast<Uint32>().value,
        sourceHeight: (_multiOut + 8).cast<Uint32>().value,
        columns: (_multiOut + 9).cast<Uint32>().value,
        rows: (_multiOut + 10).cast<Uint32>().value,
        z: (_multiOut + 11).cast<Int32>().value,
      ),
    );
  }

  @override
  CResult<RawPlacementRenderInfo> kittyGraphicsPlacementRenderInfo(
    int iterator,
    int image,
    int terminal,
  ) {
    if (iterator == 0 || image == 0 || terminal == 0) {
      return (Result.invalidValue, _emptyRenderInfo);
    }
    final out = calloc<KittyGraphicsPlacementRenderInfo>();
    out.ref.size = sizeOf<KittyGraphicsPlacementRenderInfo>();
    final code = ghostty_kitty_graphics_placement_render_info(
      Pointer<KittyGraphicsPlacementIteratorImpl>.fromAddress(iterator),
      Pointer.fromAddress(image),
      Pointer.fromAddress(terminal),
      out,
    );
    if (code != Result.success) {
      calloc.free(out);
      return (code, _emptyRenderInfo);
    }
    final info = (
      pixelWidth: out.ref.pixel_width,
      pixelHeight: out.ref.pixel_height,
      gridCols: out.ref.grid_cols,
      gridRows: out.ref.grid_rows,
      viewportCol: out.ref.viewport_col,
      viewportRow: out.ref.viewport_row,
      viewportVisible: out.ref.viewport_visible,
      sourceX: out.ref.source_x,
      sourceY: out.ref.source_y,
      sourceWidth: out.ref.source_width,
      sourceHeight: out.ref.source_height,
    );
    calloc.free(out);
    return (Result.success, info);
  }

  void _installSysLog(
    void Function(
      Pointer<Void> userdata,
      int level,
      Pointer<Uint8> scope,
      int scopeLen,
      Pointer<Uint8> message,
      int messageLen,
    )
    fn,
  ) {
    _sysLogCallable?.close();
    final callable =
        NativeCallable<
          Void Function(
            Pointer<Void>,
            UnsignedInt,
            Pointer<Uint8>,
            Size,
            Pointer<Uint8>,
            Size,
          )
        >.isolateLocal(fn);
    _sysLogCallable = callable;
    ghostty_sys_set(SysOption.log, callable.nativeFunction.cast());
  }
}

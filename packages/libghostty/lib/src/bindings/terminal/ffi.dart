import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../../generated/libghostty.g.dart' as native;
import '../../generated/libghostty_enums.g.dart';
import '../../types/types.dart';
import '../result_helpers.dart';
import '../types.dart';
import 'terminal.dart';

void _invokeOpaqueReply(
  ffi.Pointer<
    ffi.NativeFunction<
      ffi.Void Function(ffi.Pointer<ffi.Void>, ffi.Pointer<ffi.Void>)
    >
  >
  callback,
  ffi.Pointer<ffi.Void> request,
  ffi.Pointer<ffi.Void> reply,
) {
  callback
      .asFunction<
        void Function(ffi.Pointer<ffi.Void>, ffi.Pointer<ffi.Void>)
      >()(request, reply);
}

final class FfiTerminalBindings implements TerminalBindings {
  final _callbacks = <int, Map<TerminalOption, NativeCallable>>{};
  final _stringBuffers = <int, Map<TerminalOption, _StringBuffer>>{};

  ({Object error, StackTrace stackTrace})? _callbackError;

  final _outU8 = calloc<Uint8>();
  final _outU16 = calloc<Uint16>();
  final _outU32 = calloc<Uint32>();
  final _outU64 = calloc<Uint64>();
  final _outI32 = calloc<Int32>();
  final _outBool = calloc<Bool>();
  final _outModeConfig = calloc<native.TerminalModeConfig>();
  final _outStyle = calloc<native.Style>();
  final _outScrollbar = calloc<native.TerminalScrollbar>();
  final _outSize = calloc<Size>();
  final _outString = calloc<native.String>();
  final _outColor = calloc<native.ColorRgb>();
  final _multiKeys = calloc<UnsignedInt>(4);
  final _multiValues = calloc<Pointer<Void>>(4);
  final _multiOut = calloc<Uint64>(4);

  FfiTerminalBindings() {
    _outStyle.ref.size = sizeOf<native.Style>();
  }

  @override
  TerminalCompressionResult terminalCompress(
    LibGhosttyHandle terminal,
    TerminalCompressionMode mode,
  ) {
    final result = native.ghostty_terminal_compress(
      .fromAddress(terminal.value),
      mode,
      _outU32.cast(),
    );
    checkRequiredCode(result.value, operation: 'ghostty_terminal_compress');
    return .fromValue(_outU32.value);
  }

  @override
  int terminalCompressionActivity(LibGhosttyHandle terminal) {
    final result = native.ghostty_terminal_compression_activity(
      .fromAddress(terminal.value),
      _outU64,
    );
    checkRequiredCode(
      result.value,
      operation: 'ghostty_terminal_compression_activity',
    );
    return _outU64.value;
  }

  @override
  Uint8List terminalContinuationGet(LibGhosttyHandle terminal) {
    return using((arena) {
      final pointer = Pointer<native.TerminalImpl>.fromAddress(terminal.value);
      final written = arena<Size>();
      var result = native.ghostty_terminal_continuation_buf(
        pointer,
        nullptr.cast<Uint8>(),
        0,
        written,
      );
      if (result == .success) return Uint8List(0);
      if (result != .outOfSpace) {
        checkResultCode(
          result.value,
          operation: 'ghostty_terminal_continuation_buf',
        );
      }
      final capacity = written.value;
      if (capacity == 0) return Uint8List(0);
      final buffer = arena<Uint8>(capacity);
      result = native.ghostty_terminal_continuation_buf(
        pointer,
        buffer,
        capacity,
        written,
      );
      checkResultCode(
        result.value,
        operation: 'ghostty_terminal_continuation_buf',
      );
      return Uint8List.fromList(buffer.asTypedList(written.value));
    });
  }

  @override
  void terminalContinuationWrite(
    LibGhosttyHandle terminal,
    ContinuationWriter writer,
  ) {
    final callable =
        NativeCallable<
          Bool Function(Pointer<Void>, Pointer<Uint8>, Size)
        >.isolateLocal((Pointer<Void> _, Pointer<Uint8> data, int length) {
          try {
            return writer(Uint8List.fromList(data.asTypedList(length)));
          } on Object catch (error, stackTrace) {
            _captureCallbackError(error, stackTrace);
            return false;
          }
        }, exceptionalReturn: false);
    Object? resultError;
    StackTrace? resultStackTrace;
    try {
      using((arena) {
        final nativeWriter = native.Writer.$allocate(
          arena,
          write: callable.nativeFunction,
          userdata: nullptr,
        );
        try {
          checkResultCode(
            native
                .ghostty_terminal_continuation_write(
                  .fromAddress(terminal.value),
                  nativeWriter.ref,
                )
                .value,
            operation: 'ghostty_terminal_continuation_write',
          );
        } on Object catch (error, stackTrace) {
          resultError = error;
          resultStackTrace = stackTrace;
        }
      });
    } finally {
      callable.close();
    }
    _rethrowCallbackError();
    if (resultError case final error?) {
      Error.throwWithStackTrace(error, resultStackTrace!);
    }
  }

  @override
  void terminalFree(LibGhosttyHandle terminal) {
    native.ghostty_terminal_free(.fromAddress(terminal.value));
    final callbacks = _callbacks.remove(terminal.value);
    if (callbacks != null) {
      for (final callback in callbacks.values) {
        callback.close();
      }
    }
    final buffers = _stringBuffers.remove(terminal.value);
    if (buffers != null) {
      for (final buffer in buffers.values) {
        if (buffer.data != nullptr) calloc.free(buffer.data);
        calloc.free(buffer.string);
      }
    }
  }

  @override
  TerminalScreen terminalGetActiveScreen(LibGhosttyHandle terminal) {
    final result = native.ghostty_terminal_get(
      .fromAddress(terminal.value),
      .activeScreen,
      _outI32.cast(),
    );
    checkRequiredCode(result.value, operation: 'ghostty_terminal_get');
    return .fromValue(_outI32.value);
  }

  @override
  int terminalGetClipboardWriteMaxBytes(LibGhosttyHandle terminal) =>
      _getU64(terminal, .clipboardWriteMaxBytes)!;

  @override
  RgbColor? terminalGetColorBackground(LibGhosttyHandle terminal) =>
      _getColor(terminal, .colorBackground);

  @override
  RgbColor? terminalGetColorBackgroundDefault(LibGhosttyHandle terminal) =>
      _getColor(terminal, .colorBackgroundDefault);

  @override
  RgbColor? terminalGetColorCursor(LibGhosttyHandle terminal) =>
      _getColor(terminal, .colorCursor);

  @override
  RgbColor? terminalGetColorCursorDefault(LibGhosttyHandle terminal) =>
      _getColor(terminal, .colorCursorDefault);

  @override
  RgbColor? terminalGetColorForeground(LibGhosttyHandle terminal) =>
      _getColor(terminal, .colorForeground);

  @override
  RgbColor? terminalGetColorForegroundDefault(LibGhosttyHandle terminal) =>
      _getColor(terminal, .colorForegroundDefault);

  @override
  List<RgbColor> terminalGetColorPalette(LibGhosttyHandle terminal) =>
      _getPalette(terminal, .colorPalette);

  @override
  List<RgbColor> terminalGetColorPaletteDefault(LibGhosttyHandle terminal) =>
      _getPalette(terminal, .colorPaletteDefault);

  @override
  int terminalGetCols(LibGhosttyHandle terminal) =>
      _getU16(terminal, .cols, 'ghostty_terminal_get');

  @override
  int terminalGetContinuationMaxBytes(LibGhosttyHandle terminal) =>
      _getSize(terminal, .continuationMaxBytes, requiredValue: true)!;

  @override
  bool terminalGetCursorAtPrompt(LibGhosttyHandle terminal) =>
      _getBool(terminal, .cursorAtPrompt, 'ghostty_terminal_get');

  @override
  bool terminalGetCursorPendingWrap(LibGhosttyHandle terminal) =>
      _getBool(terminal, .cursorPendingWrap, 'ghostty_terminal_get');

  @override
  Style terminalGetCursorStyle(LibGhosttyHandle terminal) {
    final result = native.ghostty_terminal_get(
      .fromAddress(terminal.value),
      .cursorStyle,
      _outStyle.cast(),
    );
    checkRequiredCode(result.value, operation: 'ghostty_terminal_get');
    return _readStyle(_outStyle.ref);
  }

  @override
  bool terminalGetCursorVisible(LibGhosttyHandle terminal) =>
      _getBool(terminal, .cursorVisible, 'ghostty_terminal_get');

  @override
  int terminalGetCursorX(LibGhosttyHandle terminal) =>
      _getU16(terminal, .cursorX, 'ghostty_terminal_get');

  @override
  int terminalGetCursorY(LibGhosttyHandle terminal) =>
      _getU16(terminal, .cursorY, 'ghostty_terminal_get');

  @override
  TerminalGeometry terminalGetGeometry(LibGhosttyHandle terminal) {
    const keys = <TerminalData>[.cols, .rows, .widthPx, .heightPx];
    for (var i = 0; i < keys.length; i++) {
      _multiKeys[i] = keys[i].value;
      _multiValues[i] = (_multiOut + i).cast();
    }
    final result = native.ghostty_terminal_get_multi(
      .fromAddress(terminal.value),
      keys.length,
      _multiKeys,
      _multiValues,
      _outSize,
    );
    checkRequiredCode(result.value, operation: 'ghostty_terminal_get_multi');
    return TerminalGeometry(
      cols: (_multiOut + 0).cast<Uint16>().value,
      rows: (_multiOut + 1).cast<Uint16>().value,
      widthPx: (_multiOut + 2).cast<Uint32>().value,
      heightPx: (_multiOut + 3).cast<Uint32>().value,
    );
  }

  @override
  int terminalGetHeightPx(LibGhosttyHandle terminal) =>
      _getU32(terminal, .heightPx, 'ghostty_terminal_get');

  @override
  bool? terminalGetKittyImageMediumFile(LibGhosttyHandle terminal) =>
      _getBoolOptional(terminal, .kittyImageMediumFile);

  @override
  bool? terminalGetKittyImageMediumSharedMem(LibGhosttyHandle terminal) =>
      _getBoolOptional(terminal, .kittyImageMediumSharedMem);

  @override
  String? terminalGetKittyImageMediumTempFile(LibGhosttyHandle terminal) =>
      _getString(terminal, .kittyImageMediumTempFile);

  @override
  int? terminalGetKittyImageStorageLimit(LibGhosttyHandle terminal) =>
      _getU64(terminal, .kittyImageStorageLimit);

  @override
  int terminalGetKittyKeyboardFlags(LibGhosttyHandle terminal) {
    final result = native.ghostty_terminal_get(
      .fromAddress(terminal.value),
      .kittyKeyboardFlags,
      _outU8.cast(),
    );
    checkRequiredCode(result.value, operation: 'ghostty_terminal_get');
    return _outU8.value;
  }

  @override
  bool terminalGetMouseTracking(LibGhosttyHandle terminal) =>
      _getBool(terminal, .mouseTracking, 'ghostty_terminal_get');

  @override
  MouseShape terminalGetMouseShape(LibGhosttyHandle terminal) =>
      .fromValue(_getU32(terminal, .mouseShape, 'ghostty_terminal_get'));

  @override
  TerminalMemoryUsage terminalGetMemoryUsage(LibGhosttyHandle terminal) {
    return using((arena) {
      final value = arena<native.TerminalMemoryUsage>();
      value.ref.size = sizeOf<native.TerminalMemoryUsage>();
      final result = native.ghostty_terminal_get(
        .fromAddress(terminal.value),
        .memoryUsage,
        value.cast(),
      );
      checkRequiredCode(result.value, operation: 'ghostty_terminal_get');
      final usage = value.ref;
      return TerminalMemoryUsage(
        compressionSupported: usage.compression_supported,
        primaryPages: usage.primary_pages,
        primaryVirtualBytes: usage.primary_virtual_bytes,
        primaryResidentBytes: usage.primary_resident_bytes,
        primaryCompressedPages: usage.primary_compressed_pages,
        primaryCompressedBytes: usage.primary_compressed_bytes,
        primaryImageBytes: usage.primary_image_bytes,
        alternatePages: usage.alternate_pages,
        alternateVirtualBytes: usage.alternate_virtual_bytes,
        alternateResidentBytes: usage.alternate_resident_bytes,
        alternateCompressedPages: usage.alternate_compressed_pages,
        alternateCompressedBytes: usage.alternate_compressed_bytes,
        alternateImageBytes: usage.alternate_image_bytes,
      );
    });
  }

  @override
  String terminalGetPwd(LibGhosttyHandle terminal) =>
      _getString(terminal, .pwd, requiredValue: true)!;

  @override
  int terminalGetRows(LibGhosttyHandle terminal) =>
      _getU16(terminal, .rows, 'ghostty_terminal_get');

  @override
  int? terminalGetScrollbackMaxBytes(LibGhosttyHandle terminal) =>
      _getSize(terminal, .scrollbackMaxBytes);

  @override
  int? terminalGetScrollbackMaxLines(LibGhosttyHandle terminal) =>
      _getSize(terminal, .scrollbackMaxLines);

  @override
  int terminalGetScrollbackRows(LibGhosttyHandle terminal) =>
      _getSize(terminal, .scrollbackRows, requiredValue: true)!;

  @override
  Scrollbar terminalGetScrollbar(LibGhosttyHandle terminal) {
    final result = native.ghostty_terminal_get(
      .fromAddress(terminal.value),
      .scrollbar,
      _outScrollbar.cast(),
    );
    checkRequiredCode(result.value, operation: 'ghostty_terminal_get');
    return Scrollbar(
      total: _outScrollbar.ref.total,
      offset: _outScrollbar.ref.offset,
      visible: _outScrollbar.ref.len,
    );
  }

  @override
  String terminalGetTitle(LibGhosttyHandle terminal) =>
      _getString(terminal, .title, requiredValue: true)!;

  @override
  int terminalGetTotalRows(LibGhosttyHandle terminal) =>
      _getSize(terminal, .totalRows, requiredValue: true)!;

  @override
  bool terminalGetViewportActive(LibGhosttyHandle terminal) =>
      _getBool(terminal, .viewportActive, 'ghostty_terminal_get');

  @override
  bool terminalGetVtGround(LibGhosttyHandle terminal) =>
      _getBool(terminal, .vtGround, 'ghostty_terminal_get');

  @override
  bool terminalGetVtProcessingError(LibGhosttyHandle terminal) =>
      _getBool(terminal, .vtProcessingError, 'ghostty_terminal_get');

  @override
  int terminalGetWidthPx(LibGhosttyHandle terminal) =>
      _getU32(terminal, .widthPx, 'ghostty_terminal_get');

  @override
  bool terminalModeGet(LibGhosttyHandle terminal, int mode) {
    _outModeConfig.ref.mode = mode;
    final result = native.ghostty_terminal_get(
      .fromAddress(terminal.value),
      .mode,
      _outModeConfig.cast(),
    );
    checkRequiredCode(result.value, operation: 'ghostty_terminal_get');
    return _outModeConfig.ref.value;
  }

  @override
  void terminalModeSet(
    LibGhosttyHandle terminal,
    int mode, {
    required bool value,
  }) => _setMode(terminal, .mode, mode, value);

  @override
  void terminalModeSetDefault(
    LibGhosttyHandle terminal,
    int mode, {
    required bool value,
  }) => _setMode(terminal, .modeDefault, mode, value);

  @override
  LibGhosttyHandle terminalNew(int cols, int rows) {
    return using((arena) {
      final out = arena<Pointer<native.TerminalImpl>>();
      final result = native.ghostty_terminal_new(nullptr, out, cols, rows);
      checkRequiredCode(result.value, operation: 'ghostty_terminal_new');
      return .fromAddress(out.value.address);
    });
  }

  @override
  bool terminalPasteText(
    LibGhosttyHandle terminal,
    String text, {
    required bool allowUnsafe,
  }) {
    return using((arena) {
      final encoded = utf8.encode(text);
      final data = arena<Uint8>(encoded.isEmpty ? 1 : encoded.length);
      if (encoded.isNotEmpty) {
        data.asTypedList(encoded.length).setAll(0, encoded);
      }
      final mimeData = 'text/plain'.codeUnits;
      final mimeBytes = arena<Uint8>(mimeData.length);
      mimeBytes.asTypedList(mimeData.length).setAll(0, mimeData);
      final mimes = arena<native.String>();
      mimes.ref
        ..ptr = mimeBytes
        ..len = mimeData.length;
      final reader =
          NativeCallable<
            Bool Function(Pointer<Void>, native.String, native.Writer)
          >.isolateLocal((
            Pointer<Void> _,
            native.String mime,
            native.Writer writer,
          ) {
            if (_readString(mime) != 'text/plain') {
              return false;
            }
            final write = writer.write
                .asFunction<
                  bool Function(Pointer<Void>, Pointer<Uint8>, int)
                >();
            return write(writer.userdata, data, encoded.length);
          }, exceptionalReturn: false);
      try {
        final readerStruct = native.MimeReader.$allocate(
          arena,
          read: reader.nativeFunction.cast(),
          userdata: nullptr,
        );
        final paste = arena<native.Paste>();
        paste.ref
          ..size = sizeOf<native.Paste>()
          ..location = ClipboardLocation.standard
          ..source = PasteSource.text
          ..mimes = mimes
          ..mimes_len = 1
          ..reader = readerStruct.ref
          ..allow_unsafe = allowUnsafe;
        final written = arena<Bool>();
        final result = native.ghostty_terminal_paste(
          .fromAddress(terminal.value),
          paste,
          written,
        );
        checkResultCode(result.value, operation: 'ghostty_terminal_paste');
        return written.value;
      } finally {
        reader.close();
      }
    });
  }

  @override
  void terminalReset(LibGhosttyHandle terminal) {
    native.ghostty_terminal_reset(.fromAddress(terminal.value));
  }

  @override
  void terminalResize(
    LibGhosttyHandle terminal,
    int cols,
    int rows,
    int cellWidthPx,
    int cellHeightPx,
  ) {
    void resize() {
      final result = native.ghostty_terminal_resize(
        .fromAddress(terminal.value),
        cols,
        rows,
        cellWidthPx,
        cellHeightPx,
      );
      checkResultCode(result.value, operation: 'ghostty_terminal_resize');
    }

    if (_callbacks[terminal.value]?.isEmpty ?? true) {
      resize();
      return;
    }
    if (_callbackError != null) {
      _runNestedCallbackOperation<void>(resize);
      return;
    }
    resize();
    _rethrowCallbackError();
  }

  @override
  void terminalScrollViewport(
    LibGhosttyHandle terminal,
    TerminalScrollViewportTag tag,
    int delta,
  ) {
    using((arena) {
      final viewport = arena<native.TerminalScrollViewport>();
      viewport.ref.tagAsInt = tag.value;
      switch (tag) {
        case .row:
          viewport.ref.value.row = delta;
        case .delta:
          viewport.ref.value.delta = delta;
        case .top || .bottom:
          viewport.ref.value.delta = 0;
      }
      native.ghostty_terminal_scroll_viewport(
        .fromAddress(terminal.value),
        viewport.ref,
      );
    });
  }

  @override
  void terminalSetApcBufferLimit(LibGhosttyHandle terminal, int? bytes) =>
      _setSize(terminal, .apcMaxBytes, bytes);

  @override
  void terminalSetClipboardWriteMaxBytes(
    LibGhosttyHandle terminal,
    int? bytes,
  ) => _setSize(terminal, .clipboardWriteMaxBytes, bytes);

  @override
  void terminalSetColorBackground(LibGhosttyHandle terminal, RgbColor? color) =>
      _setColor(terminal, .colorBackground, color);

  @override
  void terminalSetColorCursor(LibGhosttyHandle terminal, RgbColor? color) =>
      _setColor(terminal, .colorCursor, color);

  @override
  void terminalSetColorForeground(LibGhosttyHandle terminal, RgbColor? color) =>
      _setColor(terminal, .colorForeground, color);

  @override
  void terminalSetColorPalette(
    LibGhosttyHandle terminal,
    List<RgbColor>? palette,
  ) {
    if (palette == null) {
      _setOption(terminal, .colorPalette, nullptr.cast());
      return;
    }
    if (palette.length != 256) {
      throw ArgumentError.value(
        palette.length,
        'palette',
        'must contain 256 colors',
      );
    }
    using((arena) {
      final values = arena<native.ColorRgb>(256);
      for (var i = 0; i < 256; i++) {
        values[i]
          ..r = palette[i].r
          ..g = palette[i].g
          ..b = palette[i].b;
      }
      _setOption(terminal, .colorPalette, values.cast());
    });
  }

  @override
  void terminalSetContinuationMaxBytes(LibGhosttyHandle terminal, int? bytes) =>
      _setSize(terminal, .continuationMaxBytes, bytes);

  @override
  void terminalSetDefaultCursorBlink(
    LibGhosttyHandle terminal, {
    bool? blinking,
  }) => _setBool(terminal, .defaultCursorBlink, blinking);

  @override
  void terminalSetDefaultCursorShape(
    LibGhosttyHandle terminal,
    TerminalCursorShape? shape,
  ) => _setI32(terminal, .defaultCursorStyle, shape?.value);

  @override
  void terminalSetGlyphProtocol(
    LibGhosttyHandle terminal, {
    required bool enabled,
  }) => _setBool(terminal, .glyphProtocol, enabled);

  @override
  void terminalSetKittyApcBufferLimit(LibGhosttyHandle terminal, int? bytes) =>
      _setSize(terminal, .apcMaxBytesKitty, bytes);

  @override
  void terminalSetKittyImageMediumFile(
    LibGhosttyHandle terminal, {
    bool? enabled,
  }) => _setBool(terminal, .kittyImageMediumFile, enabled);

  @override
  void terminalSetKittyImageMediumSharedMem(
    LibGhosttyHandle terminal, {
    bool? enabled,
  }) => _setBool(terminal, .kittyImageMediumSharedMem, enabled);

  @override
  void terminalSetKittyImageMediumTempFile(
    LibGhosttyHandle terminal,
    String? directory,
  ) => _setString(terminal, .kittyImageMediumTempFile, directory);

  @override
  void terminalSetKittyImageStorageLimit(
    LibGhosttyHandle terminal,
    int? limit,
  ) => _setU64(terminal, .kittyImageStorageLimit, limit);

  @override
  void terminalSetOnBell(LibGhosttyHandle terminal, VoidCallback? callback) {
    final callable = callback == null
        ? null
        : NativeCallable<
            Void Function(native.Terminal, Pointer<Void>)
          >.isolateLocal((native.Terminal terminal, Pointer<Void> userdata) {
            try {
              callback();
            } on Object catch (error, stackTrace) {
              _captureCallbackError(error, stackTrace);
            }
          });
    _replaceCallback(terminal, .bell, callable);
  }

  @override
  void terminalSetOnClipboardRead(
    LibGhosttyHandle terminal,
    ClipboardReadCallback? callback,
  ) {
    final callable = callback == null
        ? null
        : NativeCallable<
            Void Function(
              native.Terminal,
              Pointer<Void>,
              Pointer<native.ClipboardRead>,
            )
          >.isolateLocal((
            native.Terminal terminal,
            Pointer<Void> userdata,
            Pointer<native.ClipboardRead> pointer,
          ) {
            try {
              final read = pointer.ref;
              final request = ClipboardReadRequest(
                location: read.location,
                mimes: [
                  for (var i = 0; i < read.mimes_len; i++)
                    _readString(read.mimes[i]),
                ],
                list: read.list,
                name: _readString(read.name),
                granted: read.granted,
                canRemember: read.can_remember,
              );
              _replyClipboardRead(pointer, callback(request));
            } on Object catch (error, stackTrace) {
              _captureCallbackError(error, stackTrace);
              _replyClipboardRead(
                pointer,
                const ClipboardReadReply(result: .ioError),
              );
            }
          });
    _replaceCallback(terminal, .clipboardRead, callable);
  }

  @override
  void terminalSetOnClipboardWrite(
    LibGhosttyHandle terminal,
    ClipboardWriteCallback? callback,
  ) {
    final callable = callback == null
        ? null
        : NativeCallable<
            Void Function(
              native.Terminal,
              Pointer<Void>,
              Pointer<native.ClipboardWrite>,
            )
          >.isolateLocal((
            native.Terminal terminal,
            Pointer<Void> userdata,
            Pointer<native.ClipboardWrite> pointer,
          ) {
            try {
              final write = pointer.ref;
              final contents = [
                for (var i = 0; i < write.contents_len; i++)
                  ClipboardContent(
                    mime: utf8.decode(
                      write.contents[i].mime.ptr.asTypedList(
                        write.contents[i].mime.len,
                      ),
                    ),
                    data: Uint8List.fromList(
                      write.contents[i].data.ptr.asTypedList(
                        write.contents[i].data.len,
                      ),
                    ),
                  ),
              ];
              final result = callback(
                ClipboardWrite(
                  location: write.location,
                  contents: List.unmodifiable(contents),
                  name: _readString(write.name),
                  granted: write.granted,
                  canRemember: write.can_remember,
                ),
              );
              using((arena) {
                final reply = native.ClipboardWriteReply.$allocate(
                  arena,
                  size: sizeOf<native.ClipboardWriteReply>(),
                  result: result,
                  remember: false,
                );
                _invokeOpaqueReply(
                  write.reply.cast(),
                  pointer.cast(),
                  reply.cast(),
                );
              });
            } on Object catch (error, stackTrace) {
              _captureCallbackError(error, stackTrace);
              using((arena) {
                final reply = native.ClipboardWriteReply.$allocate(
                  arena,
                  size: sizeOf<native.ClipboardWriteReply>(),
                  result: .ioError,
                  remember: false,
                );
                _invokeOpaqueReply(
                  pointer.ref.reply.cast(),
                  pointer.cast(),
                  reply.cast(),
                );
              });
            }
          });
    _replaceCallback(terminal, .clipboardWrite, callable);
  }

  @override
  void terminalSetOnColorScheme(
    LibGhosttyHandle terminal,
    ValueGetter<ColorScheme?>? callback,
  ) {
    final callable = callback == null
        ? null
        : NativeCallable<
            Bool Function(native.Terminal, Pointer<Void>, Pointer<UnsignedInt>)
          >.isolateLocal((
            native.Terminal terminal,
            Pointer<Void> userdata,
            Pointer<UnsignedInt> output,
          ) {
            try {
              final scheme = callback();
              if (scheme == null) return false;
              output.value = scheme.value;
              return true;
            } on Object catch (error, stackTrace) {
              _captureCallbackError(error, stackTrace);
              return false;
            }
          }, exceptionalReturn: false);
    _replaceCallback(terminal, .colorScheme, callable);
  }

  @override
  void terminalSetOnDesktopNotification(
    LibGhosttyHandle terminal,
    DesktopNotificationCallback? callback,
  ) {
    final callable = callback == null
        ? null
        : NativeCallable<
            Void Function(
              native.Terminal,
              Pointer<Void>,
              Pointer<native.TerminalDesktopNotification>,
            )
          >.isolateLocal((
            native.Terminal terminal,
            Pointer<Void> userdata,
            Pointer<native.TerminalDesktopNotification> pointer,
          ) {
            try {
              final notification = pointer.ref;
              if (notification.size <
                  sizeOf<native.TerminalDesktopNotification>()) {
                return;
              }
              callback(
                DesktopNotification(
                  title: _readString(notification.title),
                  body: _readString(notification.body),
                ),
              );
            } on Object catch (error, stackTrace) {
              _captureCallbackError(error, stackTrace);
            }
          });
    _replaceCallback(terminal, .desktopNotification, callable);
  }

  @override
  void terminalSetOnDeviceAttributes(
    LibGhosttyHandle terminal,
    ValueGetter<DeviceAttributesResponse?>? callback,
  ) {
    final callable = callback == null
        ? null
        : NativeCallable<
            Bool Function(
              native.Terminal,
              Pointer<Void>,
              Pointer<native.DeviceAttributes>,
            )
          >.isolateLocal((
            native.Terminal terminal,
            Pointer<Void> userdata,
            Pointer<native.DeviceAttributes> output,
          ) {
            try {
              final attributes = callback();
              if (attributes == null) return false;
              final primary = attributes.primary;
              output.ref.primary.conformance_level = primary.conformanceLevel;
              final featureCount = primary.features.length.clamp(0, 64);
              for (var i = 0; i < featureCount; i++) {
                output.ref.primary.features[i] = primary.features[i];
              }
              output.ref.primary.num_features = featureCount;
              output.ref.secondary
                ..device_type = attributes.secondary.deviceType
                ..firmware_version = attributes.secondary.firmwareVersion
                ..rom_cartridge = attributes.secondary.romCartridge;
              output.ref.tertiary.unit_id = attributes.tertiary.unitId;
              return true;
            } on Object catch (error, stackTrace) {
              _captureCallbackError(error, stackTrace);
              return false;
            }
          }, exceptionalReturn: false);
    _replaceCallback(terminal, .deviceAttributes, callable);
  }

  @override
  void terminalSetOnEnquiry(
    LibGhosttyHandle terminal,
    ValueGetter<Uint8List>? callback,
  ) {
    const option = TerminalOption.enquiry;
    if (callback == null) {
      _replaceCallback(terminal, option, null);
      _freeStringBuffer(terminal.value, option);
      return;
    }
    final buffer = _stringBuffer(terminal.value, option);
    final callable =
        NativeCallable<
          native.String Function(native.Terminal, Pointer<Void>)
        >.isolateLocal((native.Terminal terminal, Pointer<Void> userdata) {
          try {
            final bytes = callback();
            _replaceStringData(buffer, bytes);
            return buffer.string.ref;
          } on Object catch (error, stackTrace) {
            _captureCallbackError(error, stackTrace);
            buffer.string.ref
              ..ptr = nullptr
              ..len = 0;
            return buffer.string.ref;
          }
        });
    _replaceCallback(terminal, option, callable);
  }

  @override
  void terminalSetOnProgressReport(
    LibGhosttyHandle terminal,
    TerminalProgressCallback? callback,
  ) {
    final callable = callback == null
        ? null
        : NativeCallable<
            Void Function(
              native.Terminal,
              Pointer<Void>,
              Pointer<native.TerminalProgressReport>,
            )
          >.isolateLocal((
            native.Terminal terminal,
            Pointer<Void> userdata,
            Pointer<native.TerminalProgressReport> pointer,
          ) {
            try {
              final report = pointer.ref;
              if (report.size < sizeOf<native.TerminalProgressReport>()) return;
              callback(
                TerminalProgress(
                  state: report.state,
                  progress: report.progress < 0 ? null : report.progress,
                ),
              );
            } on Object catch (error, stackTrace) {
              _captureCallbackError(error, stackTrace);
            }
          });
    _replaceCallback(terminal, .progressReport, callable);
  }

  @override
  void terminalSetOnPwdChanged(
    LibGhosttyHandle terminal,
    VoidCallback? callback,
  ) => _setVoidCallback(terminal, .pwdChanged, callback);

  @override
  void terminalSetOnSize(
    LibGhosttyHandle terminal,
    ValueGetter<TerminalSizeInfo?>? callback,
  ) {
    final callable = callback == null
        ? null
        : NativeCallable<
            Bool Function(
              native.Terminal,
              Pointer<Void>,
              Pointer<native.SizeReportSize>,
            )
          >.isolateLocal((
            native.Terminal terminal,
            Pointer<Void> userdata,
            Pointer<native.SizeReportSize> output,
          ) {
            try {
              final size = callback();
              if (size == null) return false;
              output.ref
                ..rows = size.rows
                ..columns = size.columns
                ..cell_width = size.cellWidth
                ..cell_height = size.cellHeight;
              return true;
            } on Object catch (error, stackTrace) {
              _captureCallbackError(error, stackTrace);
              return false;
            }
          }, exceptionalReturn: false);
    _replaceCallback(terminal, .size, callable);
  }

  @override
  void terminalSetOnTitleChanged(
    LibGhosttyHandle terminal,
    VoidCallback? callback,
  ) => _setVoidCallback(terminal, .titleChanged, callback);

  @override
  void terminalSetOnUnknownSequence(
    LibGhosttyHandle terminal,
    TerminalUnknownSequenceCallback? callback,
  ) {
    final callable = callback == null
        ? null
        : NativeCallable<
            Void Function(
              native.Terminal,
              Pointer<Void>,
              Pointer<native.TerminalUnknownSequence>,
            )
          >.isolateLocal((
            native.Terminal terminal,
            Pointer<Void> userdata,
            Pointer<native.TerminalUnknownSequence> pointer,
          ) {
            try {
              final sequence = pointer.ref;
              final payload = switch (sequence.tag) {
                .apc => (
                  content: _readBytes(sequence.value.apc.content),
                  truncated: sequence.value.apc.truncated,
                  terminator: null,
                ),
                .osc => (
                  content: _readBytes(sequence.value.osc.content),
                  truncated: sequence.value.osc.truncated,
                  terminator: sequence.value.osc.terminator,
                ),
              };
              callback(
                TerminalUnknownSequence(
                  tag: sequence.tag,
                  content: payload.content,
                  truncated: payload.truncated,
                  terminator: payload.terminator,
                ),
              );
            } on Object catch (error, stackTrace) {
              _captureCallbackError(error, stackTrace);
            }
          });
    _replaceCallback(terminal, .unknownSequence, callable);
  }

  @override
  void terminalSetOnWritePty(
    LibGhosttyHandle terminal,
    ValueSetter<Uint8List>? callback,
  ) {
    final callable = callback == null
        ? null
        : NativeCallable<
            Void Function(native.Terminal, Pointer<Void>, Pointer<Uint8>, Size)
          >.isolateLocal((
            native.Terminal terminal,
            Pointer<Void> userdata,
            Pointer<Uint8> data,
            int length,
          ) {
            try {
              callback(Uint8List.fromList(data.asTypedList(length)));
            } on Object catch (error, stackTrace) {
              _captureCallbackError(error, stackTrace);
            }
          });
    _replaceCallback(terminal, .writePty, callable);
  }

  @override
  void terminalSetOnXtversion(
    LibGhosttyHandle terminal,
    ValueGetter<String>? callback,
  ) {
    const option = TerminalOption.xtversion;
    if (callback == null) {
      _replaceCallback(terminal, option, null);
      _freeStringBuffer(terminal.value, option);
      return;
    }
    final buffer = _stringBuffer(terminal.value, option);
    final callable =
        NativeCallable<
          native.String Function(native.Terminal, Pointer<Void>)
        >.isolateLocal((native.Terminal terminal, Pointer<Void> userdata) {
          try {
            _replaceStringData(buffer, utf8.encode(callback()));
            return buffer.string.ref;
          } on Object catch (error, stackTrace) {
            _captureCallbackError(error, stackTrace);
            buffer.string.ref
              ..ptr = nullptr
              ..len = 0;
            return buffer.string.ref;
          }
        });
    _replaceCallback(terminal, option, callable);
  }

  @override
  void terminalSetPwd(LibGhosttyHandle terminal, String? pwd) =>
      _setString(terminal, .pwd, pwd);

  @override
  void terminalSetScrollbackMaxBytes(LibGhosttyHandle terminal, int? bytes) =>
      _setSize(terminal, .scrollbackMaxBytes, bytes);

  @override
  void terminalSetScrollbackMaxLines(LibGhosttyHandle terminal, int? lines) =>
      _setSize(terminal, .scrollbackMaxLines, lines);

  @override
  void terminalSetResizePullScrollback(
    LibGhosttyHandle terminal, {
    required bool? value,
  }) => _setBool(terminal, .resizePullScrollback, value);

  @override
  void terminalSetXtChecksumReport(
    LibGhosttyHandle terminal, {
    required bool enabled,
  }) => _setBool(terminal, .xtChecksumReport, enabled);

  @override
  void terminalSetXtChecksumExtension(LibGhosttyHandle terminal, int? value) {
    if (value == null) {
      _setOption(terminal, .xtChecksumExtension, nullptr.cast());
      return;
    }
    RangeError.checkValueInInterval(value, 0, 31, 'value');
    _outU8.value = value;
    _setOption(terminal, .xtChecksumExtension, _outU8.cast());
  }

  @override
  void terminalSetTerminfoName(LibGhosttyHandle terminal, String? name) =>
      _setString(terminal, .terminfoName, name);

  @override
  void terminalSetTitle(LibGhosttyHandle terminal, String? title) =>
      _setString(terminal, .title, title);

  @override
  void terminalSetTitleReport(
    LibGhosttyHandle terminal, {
    required bool enabled,
  }) => _setBool(terminal, .titleReport, enabled);

  @override
  void terminalSetUnknownSequenceMaxBytes(
    LibGhosttyHandle terminal,
    int? bytes,
  ) => _setSize(terminal, .unknownMaxBytes, bytes);

  @override
  void terminalVtWrite(LibGhosttyHandle terminal, Uint8List data) {
    if (data.isEmpty) return;

    void write() {
      using((arena) {
        final bytes = arena<Uint8>(data.length);
        bytes.asTypedList(data.length).setAll(0, data);
        native.ghostty_terminal_vt_write(
          .fromAddress(terminal.value),
          bytes,
          data.length,
        );
      });
    }

    if (_callbacks[terminal.value]?.isEmpty ?? true) {
      write();
      return;
    }
    if (_callbackError != null) {
      _runNestedCallbackOperation<void>(write);
      return;
    }
    write();
    _rethrowCallbackError();
  }

  @override
  int? terminalWriteUntilGround(LibGhosttyHandle terminal, Uint8List data) {
    int? write() {
      return using((arena) {
        final bytes = data.isEmpty
            ? nullptr.cast<Uint8>()
            : arena<Uint8>(data.length);
        if (data.isNotEmpty) bytes.asTypedList(data.length).setAll(0, data);
        final consumed = arena<Size>();
        final result = native.ghostty_terminal_vt_write_until_ground(
          .fromAddress(terminal.value),
          bytes,
          data.length,
          consumed,
        );
        if (result == .noValue) return null;
        checkResultCode(
          result.value,
          operation: 'ghostty_terminal_vt_write_until_ground',
        );
        return consumed.value;
      });
    }

    if (_callbacks[terminal.value]?.isEmpty ?? true) {
      return write();
    }
    if (_callbackError != null) {
      return _runNestedCallbackOperation<int?>(write);
    }
    final result = write();
    _rethrowCallbackError();
    return result;
  }

  void _captureCallbackError(Object error, StackTrace stackTrace) {
    _callbackError ??= (error: error, stackTrace: stackTrace);
  }

  void _freeStringBuffer(int handle, TerminalOption option) {
    final buffers = _stringBuffers[handle];
    final buffer = buffers?.remove(option);
    if (buffer != null) {
      if (buffer.data != nullptr) calloc.free(buffer.data);
      calloc.free(buffer.string);
    }
    if (buffers?.isEmpty ?? false) _stringBuffers.remove(handle);
  }

  bool _getBool(
    LibGhosttyHandle terminal,
    TerminalData data,
    String operation,
  ) {
    final result = native.ghostty_terminal_get(
      .fromAddress(terminal.value),
      data,
      _outBool.cast(),
    );
    checkRequiredCode(result.value, operation: operation);
    return _outBool.value;
  }

  bool? _getBoolOptional(LibGhosttyHandle terminal, TerminalData data) {
    final result = native.ghostty_terminal_get(
      .fromAddress(terminal.value),
      data,
      _outBool.cast(),
    );
    return checkOptionalCode(result.value, operation: 'ghostty_terminal_get')
        ? _outBool.value
        : null;
  }

  RgbColor? _getColor(LibGhosttyHandle terminal, TerminalData data) {
    final result = native.ghostty_terminal_get(
      .fromAddress(terminal.value),
      data,
      _outColor.cast(),
    );
    if (!checkOptionalCode(result.value, operation: 'ghostty_terminal_get')) {
      return null;
    }
    return RgbColor(_outColor.ref.r, _outColor.ref.g, _outColor.ref.b);
  }

  List<RgbColor> _getPalette(LibGhosttyHandle terminal, TerminalData data) {
    return using((arena) {
      final values = arena<native.ColorRgb>(256);
      final result = native.ghostty_terminal_get(
        .fromAddress(terminal.value),
        data,
        values.cast(),
      );
      checkRequiredCode(result.value, operation: 'ghostty_terminal_get');
      return [
        for (var i = 0; i < 256; i++)
          RgbColor(values[i].r, values[i].g, values[i].b),
      ];
    });
  }

  int? _getSize(
    LibGhosttyHandle terminal,
    TerminalData data, {
    bool requiredValue = false,
  }) {
    final result = native.ghostty_terminal_get(
      .fromAddress(terminal.value),
      data,
      _outSize.cast(),
    );
    final present = requiredValue
        ? checkRequiredCode(result.value, operation: 'ghostty_terminal_get')
        : checkOptionalCode(result.value, operation: 'ghostty_terminal_get');
    return present ? _outSize.value : null;
  }

  String? _getString(
    LibGhosttyHandle terminal,
    TerminalData data, {
    bool requiredValue = false,
  }) {
    final result = native.ghostty_terminal_get(
      .fromAddress(terminal.value),
      data,
      _outString.cast(),
    );
    final present = requiredValue
        ? checkRequiredCode(result.value, operation: 'ghostty_terminal_get')
        : checkOptionalCode(result.value, operation: 'ghostty_terminal_get');
    if (!present) return null;
    return _readString(_outString.ref);
  }

  int _getU16(LibGhosttyHandle terminal, TerminalData data, String operation) {
    final result = native.ghostty_terminal_get(
      .fromAddress(terminal.value),
      data,
      _outU16.cast(),
    );
    checkRequiredCode(result.value, operation: operation);
    return _outU16.value;
  }

  int _getU32(LibGhosttyHandle terminal, TerminalData data, String operation) {
    final result = native.ghostty_terminal_get(
      .fromAddress(terminal.value),
      data,
      _outU32.cast(),
    );
    checkRequiredCode(result.value, operation: operation);
    return _outU32.value;
  }

  int? _getU64(LibGhosttyHandle terminal, TerminalData data) {
    final result = native.ghostty_terminal_get(
      .fromAddress(terminal.value),
      data,
      _outU64.cast(),
    );
    return checkOptionalCode(result.value, operation: 'ghostty_terminal_get')
        ? _outU64.value
        : null;
  }

  void _replaceCallback(
    LibGhosttyHandle terminal,
    TerminalOption option,
    NativeCallable? callable,
  ) {
    final map = _callbacks.putIfAbsent(terminal.value, () => {});
    final previous = map[option];
    final nativeCallback =
        callable?.nativeFunction.cast<Void>() ?? nullptr.cast<Void>();
    final result = native.ghostty_terminal_set(
      .fromAddress(terminal.value),
      option,
      nativeCallback,
    );
    try {
      checkResultCode(result.value, operation: 'ghostty_terminal_set');
    } on Object {
      callable?.close();
      rethrow;
    }
    previous?.close();
    if (callable == null) {
      map.remove(option);
      if (map.isEmpty) _callbacks.remove(terminal.value);
    } else {
      map[option] = callable;
    }
  }

  void _replaceStringData(_StringBuffer buffer, List<int> bytes) {
    if (buffer.data != nullptr) calloc.free(buffer.data);
    final data = calloc<Uint8>(bytes.isEmpty ? 1 : bytes.length);
    if (bytes.isNotEmpty) data.asTypedList(bytes.length).setAll(0, bytes);
    buffer.data = data;
    buffer.string.ref
      ..ptr = data
      ..len = bytes.length;
  }

  void _replyClipboardRead(
    Pointer<native.ClipboardRead> pointer,
    ClipboardReadReply value,
  ) {
    using((arena) {
      final contents = arena<native.ClipboardContent>(value.contents.length);
      for (var i = 0; i < value.contents.length; i++) {
        final content = value.contents[i];
        final mime = utf8.encode(content.mime);
        final mimePointer = arena<Uint8>(mime.isEmpty ? 1 : mime.length);
        if (mime.isNotEmpty) {
          mimePointer.asTypedList(mime.length).setAll(0, mime);
        }
        final dataPointer = arena<Uint8>(
          content.data.isEmpty ? 1 : content.data.length,
        );
        if (content.data.isNotEmpty) {
          dataPointer.asTypedList(content.data.length).setAll(0, content.data);
        }
        contents[i]
          ..mime = (native.String.$allocate(
            arena,
            ptr: mimePointer,
            len: mime.length,
          )).ref
          ..data = (native.String.$allocate(
            arena,
            ptr: dataPointer,
            len: content.data.length,
          )).ref;
      }
      final available = arena<native.String>(value.available.length);
      for (var i = 0; i < value.available.length; i++) {
        final bytes = utf8.encode(value.available[i]);
        final bytesPointer = arena<Uint8>(bytes.isEmpty ? 1 : bytes.length);
        if (bytes.isNotEmpty) {
          bytesPointer.asTypedList(bytes.length).setAll(0, bytes);
        }
        available[i] = native.String.$allocate(
          arena,
          ptr: bytesPointer,
          len: bytes.length,
        ).ref;
      }
      final reply = native.ClipboardReadReply.$allocate(
        arena,
        size: sizeOf<native.ClipboardReadReply>(),
        result: value.result,
        contents: contents,
        contents_len: value.contents.length,
        available: available,
        available_len: value.available.length,
        remember: value.remember,
      );
      _invokeOpaqueReply(
        pointer.ref.reply.cast(),
        pointer.cast(),
        reply.cast(),
      );
    });
  }

  void _rethrowCallbackError() {
    final failure = _callbackError;
    if (failure == null) return;
    _callbackError = null;
    Error.throwWithStackTrace(failure.error, failure.stackTrace);
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

  void _setBool(LibGhosttyHandle terminal, TerminalOption option, bool? value) {
    if (value == null) {
      _setOption(terminal, option, nullptr.cast());
      return;
    }
    _outBool.value = value;
    _setOption(terminal, option, _outBool.cast());
  }

  void _setColor(
    LibGhosttyHandle terminal,
    TerminalOption option,
    RgbColor? color,
  ) {
    if (color == null) {
      _setOption(terminal, option, nullptr.cast());
      return;
    }
    _outColor.ref
      ..r = color.r
      ..g = color.g
      ..b = color.b;
    _setOption(terminal, option, _outColor.cast());
  }

  void _setI32(LibGhosttyHandle terminal, TerminalOption option, int? value) {
    if (value == null) {
      _setOption(terminal, option, nullptr.cast());
      return;
    }
    _outI32.value = value;
    _setOption(terminal, option, _outI32.cast());
  }

  void _setMode(
    LibGhosttyHandle terminal,
    TerminalOption option,
    int mode,
    bool value,
  ) {
    _outModeConfig.ref
      ..mode = mode
      ..value = value;
    _setOption(terminal, option, _outModeConfig.cast());
  }

  void _setOption(
    LibGhosttyHandle terminal,
    TerminalOption option,
    Pointer<Void> value,
  ) {
    final result = native.ghostty_terminal_set(
      .fromAddress(terminal.value),
      option,
      value,
    );
    checkResultCode(result.value, operation: 'ghostty_terminal_set');
  }

  void _setSize(LibGhosttyHandle terminal, TerminalOption option, int? value) {
    if (value == null) {
      _setOption(terminal, option, nullptr.cast());
      return;
    }
    _outSize.value = value;
    _setOption(terminal, option, _outSize.cast());
  }

  void _setString(
    LibGhosttyHandle terminal,
    TerminalOption option,
    String? value,
  ) {
    if (value == null) {
      _setOption(terminal, option, nullptr.cast());
      return;
    }
    using((arena) {
      final encoded = utf8.encode(value);
      final bytes = arena<Uint8>(encoded.isEmpty ? 1 : encoded.length);
      bytes.asTypedList(encoded.length).setAll(0, encoded);
      final string = native.String.$allocate(
        arena,
        ptr: bytes,
        len: encoded.length,
      );
      _setOption(terminal, option, string.cast());
    });
  }

  void _setU64(LibGhosttyHandle terminal, TerminalOption option, int? value) {
    if (value == null) {
      _setOption(terminal, option, nullptr.cast());
      return;
    }
    _outU64.value = value;
    _setOption(terminal, option, _outU64.cast());
  }

  void _setVoidCallback(
    LibGhosttyHandle terminal,
    TerminalOption option,
    VoidCallback? callback,
  ) {
    final callable = callback == null
        ? null
        : NativeCallable<
            Void Function(native.Terminal, Pointer<Void>)
          >.isolateLocal((native.Terminal terminal, Pointer<Void> userdata) {
            try {
              callback();
            } on Object catch (error, stackTrace) {
              _captureCallbackError(error, stackTrace);
            }
          });
    _replaceCallback(terminal, option, callable);
  }

  _StringBuffer _stringBuffer(int handle, TerminalOption option) {
    final buffers = _stringBuffers.putIfAbsent(handle, () => {});
    return buffers[option] ??= _StringBuffer(
      native.String.$allocate(calloc, ptr: nullptr.cast(), len: 0),
      nullptr.cast(),
    );
  }

  static Uint8List _readBytes(native.String value) {
    if (value.ptr == nullptr || value.len == 0) return Uint8List(0);
    return Uint8List.fromList(value.ptr.cast<Uint8>().asTypedList(value.len));
  }

  static RawColor _readColor(native.StyleColor color) => (
    tag: .fromValue(color.tag.value),
    palette: color.value.palette,
    r: color.value.rgb.r,
    g: color.value.rgb.g,
    b: color.value.rgb.b,
  );

  static String _readString(native.String value) {
    if (value.ptr == nullptr || value.len == 0) return '';
    return utf8.decode(value.ptr.cast<Uint8>().asTypedList(value.len));
  }

  static Style _readStyle(native.Style style) {
    final underlineColor = _readColor(style.underline_color);
    return Style(
      foreground: cellColorFromRaw(_readColor(style.fg_color)),
      background: cellColorFromRaw(_readColor(style.bg_color)),
      underlineColor: switch (underlineColor.tag) {
        .rgb || .palette => cellColorFromRaw(underlineColor),
        .none => null,
      },
      bold: style.bold,
      italic: style.italic,
      faint: style.faint,
      blink: style.blink,
      inverse: style.inverse,
      invisible: style.invisible,
      strikethrough: style.strikethrough,
      overline: style.overline,
      underline: .fromValue(style.underline),
    );
  }
}

final class _StringBuffer {
  final Pointer<native.String> string;
  Pointer<Uint8> data;

  _StringBuffer(this.string, this.data);
}

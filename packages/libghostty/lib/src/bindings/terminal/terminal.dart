import 'dart:typed_data';

import '../../generated/libghostty_enums.g.dart';
import '../../types/types.dart';
import '../types.dart';

abstract interface class TerminalBindings {
  TerminalCompressionResult terminalCompress(
    LibGhosttyHandle terminal,
    TerminalCompressionMode mode,
  );
  int terminalCompressionActivity(LibGhosttyHandle terminal);

  Uint8List terminalContinuationGet(LibGhosttyHandle terminal);
  void terminalContinuationWrite(
    LibGhosttyHandle terminal,
    ContinuationWriter writer,
  );

  void terminalFree(LibGhosttyHandle terminal);
  TerminalScreen terminalGetActiveScreen(LibGhosttyHandle terminal);
  int terminalGetClipboardWriteMaxBytes(LibGhosttyHandle terminal);
  RgbColor? terminalGetColorBackground(LibGhosttyHandle terminal);
  RgbColor? terminalGetColorBackgroundDefault(LibGhosttyHandle terminal);
  RgbColor? terminalGetColorCursor(LibGhosttyHandle terminal);
  RgbColor? terminalGetColorCursorDefault(LibGhosttyHandle terminal);
  RgbColor? terminalGetColorForeground(LibGhosttyHandle terminal);
  RgbColor? terminalGetColorForegroundDefault(LibGhosttyHandle terminal);
  List<RgbColor> terminalGetColorPalette(LibGhosttyHandle terminal);
  List<RgbColor> terminalGetColorPaletteDefault(LibGhosttyHandle terminal);
  int terminalGetCols(LibGhosttyHandle terminal);
  int terminalGetContinuationMaxBytes(LibGhosttyHandle terminal);
  bool terminalGetCursorAtPrompt(LibGhosttyHandle terminal);
  bool terminalGetCursorPendingWrap(LibGhosttyHandle terminal);
  Style terminalGetCursorStyle(LibGhosttyHandle terminal);
  bool terminalGetCursorVisible(LibGhosttyHandle terminal);
  int terminalGetCursorX(LibGhosttyHandle terminal);
  int terminalGetCursorY(LibGhosttyHandle terminal);
  TerminalGeometry terminalGetGeometry(LibGhosttyHandle terminal);
  int terminalGetHeightPx(LibGhosttyHandle terminal);
  bool? terminalGetKittyImageMediumFile(LibGhosttyHandle terminal);
  bool? terminalGetKittyImageMediumSharedMem(LibGhosttyHandle terminal);
  String? terminalGetKittyImageMediumTempFile(LibGhosttyHandle terminal);
  int? terminalGetKittyImageStorageLimit(LibGhosttyHandle terminal);
  int terminalGetKittyKeyboardFlags(LibGhosttyHandle terminal);
  TerminalMemoryUsage terminalGetMemoryUsage(LibGhosttyHandle terminal);
  bool terminalGetMouseTracking(LibGhosttyHandle terminal);
  MouseShape terminalGetMouseShape(LibGhosttyHandle terminal);
  String terminalGetPwd(LibGhosttyHandle terminal);
  int terminalGetRows(LibGhosttyHandle terminal);
  int? terminalGetScrollbackMaxBytes(LibGhosttyHandle terminal);
  int? terminalGetScrollbackMaxLines(LibGhosttyHandle terminal);
  int terminalGetScrollbackRows(LibGhosttyHandle terminal);
  Scrollbar terminalGetScrollbar(LibGhosttyHandle terminal);
  String terminalGetTitle(LibGhosttyHandle terminal);
  int terminalGetTotalRows(LibGhosttyHandle terminal);
  bool terminalGetViewportActive(LibGhosttyHandle terminal);
  bool terminalGetVtGround(LibGhosttyHandle terminal);
  bool terminalGetVtProcessingError(LibGhosttyHandle terminal);
  int terminalGetWidthPx(LibGhosttyHandle terminal);

  bool terminalModeGet(LibGhosttyHandle terminal, int mode);
  void terminalModeSet(
    LibGhosttyHandle terminal,
    int mode, {
    required bool value,
  });
  void terminalModeSetDefault(
    LibGhosttyHandle terminal,
    int mode, {
    required bool value,
  });

  LibGhosttyHandle terminalNew(int cols, int rows);
  bool terminalPasteText(
    LibGhosttyHandle terminal,
    String text, {
    required bool allowUnsafe,
  });
  void terminalReset(LibGhosttyHandle terminal);

  void terminalResize(
    LibGhosttyHandle terminal,
    int cols,
    int rows,
    int cellWidthPx,
    int cellHeightPx,
  );
  void terminalScrollViewport(
    LibGhosttyHandle terminal,
    TerminalScrollViewportTag tag,
    int delta,
  );
  void terminalSetApcBufferLimit(LibGhosttyHandle terminal, int? bytes);
  void terminalSetClipboardWriteMaxBytes(LibGhosttyHandle terminal, int? bytes);
  void terminalSetColorBackground(LibGhosttyHandle terminal, RgbColor? color);
  void terminalSetColorCursor(LibGhosttyHandle terminal, RgbColor? color);
  void terminalSetColorForeground(LibGhosttyHandle terminal, RgbColor? color);
  void terminalSetColorPalette(
    LibGhosttyHandle terminal,
    List<RgbColor>? palette,
  );
  void terminalSetContinuationMaxBytes(LibGhosttyHandle terminal, int? bytes);
  void terminalSetDefaultCursorBlink(
    LibGhosttyHandle terminal, {
    bool? blinking,
  });
  void terminalSetDefaultCursorShape(
    LibGhosttyHandle terminal,
    TerminalCursorShape? shape,
  );
  void terminalSetGlyphProtocol(
    LibGhosttyHandle terminal, {
    required bool enabled,
  });
  void terminalSetKittyApcBufferLimit(LibGhosttyHandle terminal, int? bytes);
  void terminalSetKittyImageMediumFile(
    LibGhosttyHandle terminal, {
    bool? enabled,
  });
  void terminalSetKittyImageMediumSharedMem(
    LibGhosttyHandle terminal, {
    bool? enabled,
  });
  void terminalSetKittyImageMediumTempFile(
    LibGhosttyHandle terminal,
    String? directory,
  );
  void terminalSetKittyImageStorageLimit(LibGhosttyHandle terminal, int? limit);
  void terminalSetOnBell(LibGhosttyHandle terminal, VoidCallback? callback);
  void terminalSetOnClipboardRead(
    LibGhosttyHandle terminal,
    ClipboardReadCallback? callback,
  );
  void terminalSetOnClipboardWrite(
    LibGhosttyHandle terminal,
    ClipboardWriteCallback? callback,
  );
  void terminalSetOnColorScheme(
    LibGhosttyHandle terminal,
    ValueGetter<ColorScheme?>? callback,
  );
  void terminalSetOnDesktopNotification(
    LibGhosttyHandle terminal,
    DesktopNotificationCallback? callback,
  );
  void terminalSetOnDeviceAttributes(
    LibGhosttyHandle terminal,
    ValueGetter<DeviceAttributesResponse?>? callback,
  );
  void terminalSetOnEnquiry(
    LibGhosttyHandle terminal,
    ValueGetter<Uint8List>? callback,
  );
  void terminalSetOnProgressReport(
    LibGhosttyHandle terminal,
    TerminalProgressCallback? callback,
  );
  void terminalSetOnPwdChanged(
    LibGhosttyHandle terminal,
    VoidCallback? callback,
  );
  void terminalSetOnSize(
    LibGhosttyHandle terminal,
    ValueGetter<TerminalSizeInfo?>? callback,
  );
  void terminalSetOnTitleChanged(
    LibGhosttyHandle terminal,
    VoidCallback? callback,
  );
  void terminalSetOnUnknownSequence(
    LibGhosttyHandle terminal,
    TerminalUnknownSequenceCallback? callback,
  );
  void terminalSetOnWritePty(
    LibGhosttyHandle terminal,
    ValueSetter<Uint8List>? callback,
  );
  void terminalSetOnXtversion(
    LibGhosttyHandle terminal,
    ValueGetter<String>? callback,
  );

  void terminalSetPwd(LibGhosttyHandle terminal, String? pwd);
  void terminalSetScrollbackMaxBytes(LibGhosttyHandle terminal, int? bytes);
  void terminalSetScrollbackMaxLines(LibGhosttyHandle terminal, int? lines);
  void terminalSetResizePullScrollback(
    LibGhosttyHandle terminal, {
    required bool? value,
  });
  void terminalSetTerminfoName(LibGhosttyHandle terminal, String? name);
  void terminalSetTitle(LibGhosttyHandle terminal, String? title);
  void terminalSetTitleReport(
    LibGhosttyHandle terminal, {
    required bool enabled,
  });
  void terminalSetUnknownSequenceMaxBytes(
    LibGhosttyHandle terminal,
    int? bytes,
  );
  void terminalSetXtChecksumExtension(LibGhosttyHandle terminal, int? value);
  void terminalSetXtChecksumReport(
    LibGhosttyHandle terminal, {
    required bool enabled,
  });
  void terminalVtWrite(LibGhosttyHandle terminal, Uint8List data);
  int? terminalWriteUntilGround(LibGhosttyHandle terminal, Uint8List data);
}

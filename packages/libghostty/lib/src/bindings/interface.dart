import 'dart:typed_data';

import '../ffi/libghostty_enums.g.dart';
import 'types/types.dart';

export 'types/types.dart';

/// Platform-independent interface for libghostty-vt bindings.
///
/// Implemented by `NativeBindings` (dart:ffi) and `WasmBindings`
/// (dart:js_interop). Handles are opaque `int` values on both platforms.
///
/// Methods that wrap C functions returning `GhosttyResult` return a [Result]
/// enum value. For methods that also produce a value, the return type is a
/// [CResult] record. Callers decide how to handle non-success results
/// (e.g. via [checkCode] or [check]).
abstract interface class GhosttyBindings {
  CResult<int> keyEventNew();
  void keyEventFree(int handle);
  void keyEventSetAction(int handle, KeyAction action);
  KeyAction keyEventGetAction(int handle);
  void keyEventSetKey(int handle, Key key);
  Key keyEventGetKey(int handle);
  void keyEventSetMods(int handle, int mods);
  int keyEventGetMods(int handle);
  void keyEventSetConsumedMods(int handle, int mods);
  int keyEventGetConsumedMods(int handle);
  void keyEventSetComposing(int handle, {required bool composing});
  bool keyEventGetComposing(int handle);
  void keyEventSetUtf8(int handle, String? text);
  String? keyEventGetUtf8(int handle);
  void keyEventSetUnshiftedCodepoint(int handle, int codepoint);
  int keyEventGetUnshiftedCodepoint(int handle);

  CResult<int> keyEncoderNew();
  void keyEncoderFree(int handle);
  void keyEncoderSetBoolOpt(
    int handle,
    KeyEncoderOption option, {
    required bool value,
  });
  void keyEncoderSetKittyFlags(int handle, int flags);
  void keyEncoderSetOptionAsAlt(int handle, OptionAsAlt value);
  void keyEncoderSetOptFromTerminal(int encoder, int terminal);
  CResult<String> keyEncoderEncode(int encoder, int event);

  CResult<int> mouseEventNew();
  void mouseEventFree(int handle);
  void mouseEventSetAction(int handle, MouseAction action);
  MouseAction mouseEventGetAction(int handle);
  void mouseEventSetButton(int handle, MouseButton button);
  void mouseEventClearButton(int handle);

  CResult<MouseButton> mouseEventGetButton(int handle);
  void mouseEventSetMods(int handle, int mods);
  int mouseEventGetMods(int handle);
  void mouseEventSetPosition(int handle, double x, double y);
  (double x, double y) mouseEventGetPosition(int handle);

  CResult<int> mouseEncoderNew();
  void mouseEncoderFree(int handle);
  void mouseEncoderSetBoolOpt(
    int handle,
    MouseEncoderOption option, {
    required bool value,
  });
  void mouseEncoderSetTrackingMode(int handle, MouseTrackingMode mode);
  void mouseEncoderSetFormat(int handle, MouseFormat format);
  void mouseEncoderSetSize(int handle, MouseEncoderSize size);
  void mouseEncoderSetOptFromTerminal(int encoder, int terminal);
  void mouseEncoderReset(int handle);
  CResult<String> mouseEncoderEncode(int encoder, int event);

  CResult<int> oscNew();
  void oscFree(int handle);
  void oscFeedByte(int handle, int byte);
  int oscEnd(int handle, int terminator);
  OscCommandType oscCommandType(int command);
  String? oscCommandWindowTitle(int command);
  void oscReset(int handle);

  CResult<int> sgrNew();
  void sgrFree(int handle);
  Result sgrSetParams(int handle, List<int> params, List<String>? separators);
  SgrAttribute? sgrNext(int handle);
  void sgrReset(int handle);

  bool pasteIsSafe(String data);

  double colorContrast(RgbColor a, RgbColor b);
  double colorLuminance(RgbColor color);
  double colorPerceivedLuminance(RgbColor color);
  List<RgbColor> colorPaletteDefault();
  List<RgbColor> colorPaletteGenerate({
    List<RgbColor>? base,
    Set<int> skip = const {},
    required RgbColor background,
    required RgbColor foreground,
    required bool harmonious,
  });
  CResult<RgbColor> colorParse(String value);
  CResult<({int index, RgbColor color})> colorParsePaletteEntry(String value);
  CResult<RgbColor> colorParseX11(String name);
  List<X11ColorName> colorX11Names();
  CResult<String> colorSchemeReportEncode(ColorScheme scheme);

  int unicodeCodepointWidth(int codepoint);
  ({int consumed, int width}) unicodeGraphemeWidth(List<int> codepoints);

  CResult<int> terminalNew(int cols, int rows);
  void terminalFree(int handle);
  void terminalVtWrite(int handle, Uint8List data);
  Result terminalResize(
    int handle,
    int cols,
    int rows,
    int cellWidthPx,
    int cellHeightPx,
  );
  void terminalReset(int handle);
  void terminalScrollViewport(
    int handle,
    TerminalScrollViewportTag tag,
    int delta,
  );
  CResult<int> terminalCompressionActivity(int handle);
  CResult<TerminalCompressionResult> terminalCompress(
    int handle,
    TerminalCompressionMode mode,
  );
  CResult<int> terminalGetCols(int handle);
  CResult<int> terminalGetRows(int handle);
  CResult<int> terminalGetCursorX(int handle);
  CResult<int> terminalGetCursorY(int handle);
  CResult<bool> terminalGetCursorVisible(int handle);
  CResult<bool> terminalGetCursorPendingWrap(int handle);
  CResult<TerminalScreen> terminalGetActiveScreen(int handle);
  CResult<int> terminalGetKittyKeyboardFlags(int handle);
  CResult<Scrollbar> terminalGetScrollbar(int handle);
  CResult<bool> terminalModeGet(int handle, int mode);
  Result terminalModeSet(int handle, int mode, {required bool value});
  Result terminalModeSetDefault(int handle, int mode, {required bool value});
  Result terminalSetTitleReport(int handle, {required bool enabled});
  CResult<String> terminalGetTitle(int handle);
  CResult<String> terminalGetPwd(int handle);
  CResult<int> terminalGetTotalRows(int handle);
  CResult<int> terminalGetScrollbackRows(int handle);
  CResult<int> terminalGetScrollbackMaxBytes(int handle);
  CResult<int> terminalGetScrollbackMaxLines(int handle);
  CResult<int> terminalGetWidthPx(int handle);
  CResult<int> terminalGetHeightPx(int handle);
  CResult<TerminalGeometry> terminalGetGeometry(int handle);
  CResult<bool> terminalGetViewportActive(int handle);
  CResult<bool> terminalGetVtProcessingError(int handle);
  CResult<Uint8List> terminalContinuationGet(int handle);
  CResult<int> terminalGetContinuationMaxBytes(int handle);
  Result terminalSetContinuationMaxBytes(int handle, int? bytes);
  Result terminalSetTitle(int handle, String? title);
  Result terminalSetPwd(int handle, String? pwd);
  Result terminalSetDefaultCursorShape(int handle, CursorShape? shape);
  Result terminalSetDefaultCursorBlink(int handle, {bool? blinking});
  Result terminalSetGlyphProtocol(int handle, {required bool enabled});
  Result terminalSetColorForeground(int handle, RgbColor? color);
  Result terminalSetColorBackground(int handle, RgbColor? color);
  Result terminalSetColorCursor(int handle, RgbColor? color);
  Result terminalSetColorPalette(int handle, List<RgbColor>? palette);

  CResult<RgbColor> terminalGetColorForeground(int handle);
  CResult<RgbColor> terminalGetColorBackground(int handle);
  CResult<RgbColor> terminalGetColorCursor(int handle);
  CResult<List<RgbColor>> terminalGetColorPalette(int handle);

  CResult<RgbColor> terminalGetColorForegroundDefault(int handle);
  CResult<RgbColor> terminalGetColorBackgroundDefault(int handle);
  CResult<RgbColor> terminalGetColorCursorDefault(int handle);
  CResult<List<RgbColor>> terminalGetColorPaletteDefault(int handle);

  CResult<Style> terminalGetCursorStyle(int handle);
  CResult<bool> terminalGetMouseTracking(int handle);

  CResult<int> terminalGetKittyImageStorageLimit(int handle);
  CResult<bool> terminalGetKittyImageMediumFile(int handle);
  CResult<String> terminalGetKittyImageMediumTempFile(int handle);
  CResult<bool> terminalGetKittyImageMediumSharedMem(int handle);
  Result terminalSetKittyImageStorageLimit(int handle, int? limit);
  Result terminalSetKittyImageMediumFile(int handle, {bool? enabled});
  Result terminalSetKittyImageMediumTempFile(int handle, String? directory);
  Result terminalSetKittyImageMediumSharedMem(int handle, {bool? enabled});
  Result terminalSetApcBufferLimit(int handle, int? bytes);
  Result terminalSetKittyApcBufferLimit(int handle, int? bytes);
  Result terminalSetScrollbackMaxBytes(int handle, int? bytes);
  Result terminalSetScrollbackMaxLines(int handle, int? lines);

  CResult<Uint8List> pasteEncode(String data, {required bool bracketed});

  void terminalSetOnWritePty(int handle, ValueSetter<Uint8List>? callback);
  void terminalSetOnBell(int handle, VoidCallback? callback);
  void terminalSetOnClipboardWrite(
    int handle,
    ClipboardWriteCallback? callback,
  );
  void terminalSetOnDesktopNotification(
    int handle,
    DesktopNotificationCallback? callback,
  );
  void terminalSetOnProgressReport(
    int handle,
    TerminalProgressCallback? callback,
  );
  void terminalSetOnTitleChanged(int handle, VoidCallback? callback);
  void terminalSetOnPwdChanged(int handle, VoidCallback? callback);
  void terminalSetOnEnquiry(int handle, ValueGetter<Uint8List>? callback);
  void terminalSetOnXtversion(int handle, ValueGetter<String>? callback);
  void terminalSetOnColorScheme(
    int handle,
    ValueGetter<ColorScheme?>? callback,
  );
  void terminalSetOnSize(int handle, ValueGetter<TerminalSizeInfo?>? callback);
  void terminalSetOnDeviceAttributes(
    int handle,
    ValueGetter<DeviceAttributesResponse?>? callback,
  );
  void terminalDisposeCallbacks(int handle);

  void sysSetLogCallback(SysLogCallback callback);
  void sysSetLogToStderr();
  void sysClearLogCallback();

  void sysSetPngDecoder(PngDecoder decoder);
  void sysClearPngDecoder();

  /// Returns an opaque kitty graphics storage handle for [handle], or 0
  /// when kitty graphics are disabled in the native library build.
  int kittyGraphicsGet(int handle);

  /// Returns an opaque kitty image handle for [imageId] under
  /// [graphics], or 0 when no image with that id exists.
  int kittyGraphicsImage(int graphics, int imageId);

  CResult<int> kittyGraphicsImageGetId(int image);
  CResult<int> kittyGraphicsImageGetNumber(int image);
  CResult<int> kittyGraphicsImageGetWidth(int image);
  CResult<int> kittyGraphicsImageGetHeight(int image);
  CResult<KittyImageFormat> kittyGraphicsImageGetFormat(int image);
  CResult<KittyImageCompression> kittyGraphicsImageGetCompression(int image);
  CResult<int> kittyGraphicsImageGetGeneration(int image);
  CResult<int> kittyGraphicsGetGeneration(int graphics);

  /// Returns a borrowed view of the image's raw pixel bytes. Valid only
  /// until the next mutating terminal call.
  CResult<Uint8List> kittyGraphicsImageGetPixelData(int image);

  /// Creates a placement iterator. Returns an opaque handle the caller
  /// must pass to [kittyGraphicsPlacementIteratorFree].
  CResult<int> kittyGraphicsPlacementIteratorNew();
  void kittyGraphicsPlacementIteratorFree(int iterator);

  /// Populates [iterator] with the current placements in [graphics].
  /// Data yielded by the iterator is valid only until the next mutating
  /// terminal call.
  Result kittyGraphicsGetPlacements(int graphics, int iterator);

  Result kittyGraphicsPlacementIteratorSetLayer(
    int iterator,
    KittyPlacementLayer layer,
  );

  /// Advances to the next placement. Returns false when exhausted.
  bool kittyGraphicsPlacementNext(int iterator);

  CResult<RawPlacement> kittyGraphicsPlacementGet(int iterator);

  /// Computes full rendering geometry for the iterator's current
  /// placement. Returns [Result.noValue] when the placement is fully
  /// off-screen or virtual.
  CResult<RawPlacementRenderInfo> kittyGraphicsPlacementRenderInfo(
    int iterator,
    int image,
    int terminal,
  );

  CResult<int> renderStateNew();
  void renderStateFree(int handle);
  Result renderStateBeginUpdate(int state, int terminal);
  Result renderStateEndUpdate(int state);
  Result renderStateUpdate(int state, int terminal);
  CResult<int> renderStateGetCols(int state);
  CResult<int> renderStateGetRows(int state);
  CResult<RenderStateDirty> renderStateGetDirty(int state);
  CResult<RawRenderStateSummary> renderStateGetSummary(int state);
  Result renderStateSetDirty(int state, RenderStateDirty dirty);
  CResult<TerminalColors> renderStateGetColors(int state);
  CResult<RenderStateCursorVisualStyle> renderStateGetCursorVisualStyle(
    int state,
  );
  CResult<bool> renderStateGetCursorVisible(int state);
  CResult<bool> renderStateGetCursorBlinking(int state);
  CResult<bool> renderStateGetCursorPasswordInput(int state);
  CResult<bool> renderStateGetCursorInViewport(int state);
  CResult<int> renderStateGetCursorViewportX(int state);
  CResult<int> renderStateGetCursorViewportY(int state);
  CResult<bool> renderStateGetCursorViewportWideTail(int state);
  CResult<RawRenderStateCursor> renderStateGetCursor(int state);

  CResult<int> rowIteratorNew();
  void rowIteratorFree(int handle);

  /// Populates the iterator from the render state and resets its position.
  Result rowIteratorInit(int iterator, int renderState);
  bool rowIteratorNext(int iterator);
  CResult<bool> rowIteratorGetDirty(int iterator);
  CResult<RawRowIteratorSummary> rowIteratorGetSummary(int iterator);
  Result rowIteratorSetDirty(int iterator, {required bool dirty});
  CResult<int> rowIteratorGetRawRow(int iterator);
  CResult<({int startCol, int endCol})> rowIteratorGetSelection(int iterator);

  CResult<int> rowCellsNew();
  void rowCellsFree(int handle);

  /// Populates the cells from the current row in the iterator.
  Result rowCellsInit(int cells, int iterator);
  bool rowCellsNext(int cells);
  Result rowCellsSelect(int cells, int x);
  CResult<int> rowCellsGetRawCell(int cells);
  CResult<RawRowCellsSummary> rowCellsGetSummary(int cells);
  CResult<Style> rowCellsGetStyle(int cells);
  CResult<int> rowCellsGetGraphemeLen(int cells);
  CResult<List<int>> rowCellsGetGraphemes(int cells, int len);
  CResult<String> rowCellsGetGraphemesUtf8(int cells);
  CResult<bool> rowCellsGetHasStyling(int cells);
  CResult<bool> rowCellsGetSelected(int cells);
  CResult<RgbColor> rowCellsGetBgColor(int cells);
  CResult<RgbColor> rowCellsGetFgColor(int cells);
  CResult<int> rowCellsGetBgColorArgb(int cells);
  CResult<int> rowCellsGetFgColorArgb(int cells);

  CResult<int> cellGetCodepoint(int cell);
  CResult<RawCellSummary> cellGetSummary(int cell);
  CResult<CellContentTag> cellGetContentTag(int cell);
  CResult<CellWide> cellGetWide(int cell);
  CResult<bool> cellGetHasText(int cell);
  CResult<bool> cellGetHasStyling(int cell);
  CResult<int> cellGetStyleId(int cell);
  CResult<bool> cellGetHasHyperlink(int cell);
  CResult<bool> cellGetProtected(int cell);
  CResult<CellSemanticContent> cellGetSemanticContent(int cell);
  CResult<int> cellGetColorPalette(int cell);
  CResult<RgbColor> cellGetColorRgb(int cell);

  CResult<bool> rowGetWrap(int row);
  CResult<bool> rowGetWrapContinuation(int row);
  CResult<bool> rowGetGrapheme(int row);
  CResult<bool> rowGetStyled(int row);
  CResult<bool> rowGetHyperlink(int row);
  CResult<RowSemanticPrompt> rowGetSemanticPrompt(int row);
  CResult<bool> rowGetKittyVirtualPlaceholder(int row);
  CResult<bool> rowGetDirty(int row);
  CResult<RawRowSummary> rowGetSummary(int row);

  CResult<String> focusEncode(FocusEvent event);

  CResult<int> buildInfo(BuildInfo data);
  CResult<bool> buildInfoBool(BuildInfo data);
  CResult<String> buildInfoString(BuildInfo data);

  CResult<String> modeReportEncode(int mode, ModeReportState state);

  CResult<String> sizeReportEncode(
    SizeReportStyle style,
    int rows,
    int columns,
    int cellWidth,
    int cellHeight,
  );

  Style styleDefault();
  bool styleIsDefault(Style style);

  CResult<RawGridRef> terminalGridRef(
    int terminal,
    PointTag pointTag,
    Position position,
  );
  CResult<int> terminalGridRefTrack(
    int terminal,
    PointTag pointTag,
    Position position,
  );
  CResult<Position> terminalPointFromGridRef(
    int terminal,
    RawGridRef ref,
    PointTag pointTag,
  );
  CResult<int> gridRefCell(RawGridRef ref);
  CResult<int> gridRefRow(RawGridRef ref);
  CResult<Style> gridRefStyle(RawGridRef ref);
  CResult<List<int>> gridRefGraphemes(RawGridRef ref);
  CResult<String> gridRefHyperlinkUri(RawGridRef ref);
  void trackedGridRefFree(int ref);
  bool trackedGridRefHasValue(int ref);
  CResult<Position> trackedGridRefPoint(int ref, PointTag pointTag);
  Result trackedGridRefSet(
    int ref,
    int terminal,
    PointTag pointTag,
    Position position,
  );
  CResult<RawGridRef> trackedGridRefSnapshot(int ref);

  CResult<RawSelection?> terminalGetSelection(int handle);
  Result terminalSetSelection(int handle, RawSelection? selection);
  CResult<RawSelection?> terminalSelectAll(int terminal);
  CResult<RawSelection?> terminalSelectWord(
    int terminal,
    RawGridRef ref, {
    List<int>? boundaryCodepoints,
  });
  CResult<RawSelection?> terminalSelectWordBetween(
    int terminal,
    RawGridRef start,
    RawGridRef end, {
    List<int>? boundaryCodepoints,
  });
  CResult<RawSelection?> terminalSelectLine(
    int terminal,
    RawGridRef ref, {
    List<int>? whitespace,
    bool semanticPromptBoundary = false,
  });
  CResult<RawSelection?> terminalSelectOutput(int terminal, RawGridRef ref);
  CResult<RawSelection?> terminalSelectionAdjust(
    int terminal,
    RawSelection selection,
    SelectionAdjust adjustment,
  );
  CResult<SelectionOrder> terminalSelectionOrder(
    int terminal,
    RawSelection selection,
  );
  CResult<RawSelection?> terminalSelectionOrdered(
    int terminal,
    RawSelection selection,
    SelectionOrder desired,
  );
  CResult<bool> terminalSelectionContains(
    int terminal,
    RawSelection selection,
    PointTag pointTag,
    Position position,
  );
  CResult<bool> terminalSelectionEqual(
    int terminal,
    RawSelection a,
    RawSelection b,
  );
  CResult<String> terminalSelectionFormat(
    int terminal,
    FormatterFormat format, {
    bool unwrap = false,
    bool trim = false,
    RawSelection? selection,
  });

  CResult<int> selectionGestureNew();
  void selectionGestureFree(int gesture, int terminal);
  void selectionGestureReset(int gesture, int terminal);
  CResult<RawSelection?> selectionGestureEvent(
    int gesture,
    int terminal,
    int event,
  );
  CResult<int> selectionGestureEventNew(SelectionGestureEventType type);
  void selectionGestureEventFree(int event);
  Result selectionGestureEventClear(
    int event,
    SelectionGestureEventOption option,
  );
  Result selectionGestureEventSetRef(int event, RawGridRef ref);
  Result selectionGestureEventSetPosition(int event, double x, double y);
  Result selectionGestureEventSetRepeatDistance(int event, double value);
  Result selectionGestureEventSetTimeNs(int event, int value);
  Result selectionGestureEventSetRepeatIntervalNs(int event, int value);
  Result selectionGestureEventSetWordBoundaryCodepoints(
    int event,
    List<int> codepoints,
  );
  Result selectionGestureEventSetBehaviors(
    int event,
    SelectionGestureBehavior singleClick,
    SelectionGestureBehavior doubleClick,
    SelectionGestureBehavior tripleClick,
  );
  Result selectionGestureEventSetRectangle(int event, {required bool value});
  Result selectionGestureEventSetGeometry(
    int event, {
    required int columns,
    required int cellWidth,
    required int paddingLeft,
    required int screenHeight,
  });
  Result selectionGestureEventSetViewport(
    int event, {
    required Position position,
  });
  CResult<int> selectionGestureGetClickCount(int gesture, int terminal);
  CResult<bool> selectionGestureGetDragged(int gesture, int terminal);
  CResult<SelectionGestureAutoscroll> selectionGestureGetAutoscroll(
    int gesture,
    int terminal,
  );
  CResult<SelectionGestureBehavior> selectionGestureGetBehavior(
    int gesture,
    int terminal,
  );
  CResult<RawGridRef> selectionGestureGetAnchor(int gesture, int terminal);
  CResult<RawSelectionGestureState> selectionGestureGetState(
    int gesture,
    int terminal,
  );

  CResult<int> formatterTerminalNew(
    int terminal,
    FormatterFormat format, {
    bool unwrap = false,
    bool trim = false,
    FormatterExtra extra = const FormatterExtra(),
    RawSelection? selection,
  });
  void formatterFree(int formatter);
  CResult<String> formatterFormat(int formatter);
}

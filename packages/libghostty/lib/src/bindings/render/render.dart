import '../../generated/libghostty_enums.g.dart';
import '../../types/types.dart';
import '../types.dart';

abstract interface class RenderBindings {
  int cellGetCodepoint(RawCell cell);
  int cellGetColorPalette(RawCell cell);
  RgbColor cellGetColorRgb(RawCell cell);
  CellContentTag cellGetContentTag(RawCell cell);
  bool cellGetHasHyperlink(RawCell cell);
  bool cellGetHasStyling(RawCell cell);
  bool cellGetHasText(RawCell cell);
  bool cellGetProtected(RawCell cell);
  CellSemanticContent cellGetSemanticContent(RawCell cell);
  int cellGetStyleId(RawCell cell);
  RawCellSummary cellGetSummary(RawCell cell);
  CellWide cellGetWide(RawCell cell);
  bool decodeRawCell(RawCellsView view, int index, RawCellData output);

  RawCell gridRefCell(RawGridRef ref);
  List<int> gridRefGraphemes(RawGridRef ref);
  String? gridRefHyperlinkUri(RawGridRef ref);
  RawRow gridRefRow(RawGridRef ref);
  Style gridRefStyle(RawGridRef ref);

  void renderStateBeginUpdate(
    LibGhosttyHandle state,
    LibGhosttyHandle terminal,
  );
  void renderStateClean(LibGhosttyHandle state);
  void renderStateEndUpdate(LibGhosttyHandle state);
  void renderStateFree(LibGhosttyHandle state);
  TerminalColors renderStateGetColors(LibGhosttyHandle state);
  int renderStateGetCols(LibGhosttyHandle state);

  RenderStateCursor renderStateGetCursor(LibGhosttyHandle state);
  RenderStateDirty renderStateGetDirty(LibGhosttyHandle state);
  int renderStateGetRows(LibGhosttyHandle state);
  RenderOverscan renderStateGetOverscan(LibGhosttyHandle state);
  RenderOverscan renderStateGetOverscanRequest(LibGhosttyHandle state);
  RawRenderStateSummary renderStateGetSummary(LibGhosttyHandle state);
  LibGhosttyHandle renderStateNew();
  void renderStateSetDirty(LibGhosttyHandle state, RenderStateDirty dirty);
  void renderStateSetOverscanRequest(
    LibGhosttyHandle state,
    RenderOverscan overscan,
  );
  void renderStateUpdate(LibGhosttyHandle state, LibGhosttyHandle terminal);

  void rowCellsFree(LibGhosttyHandle cells);
  RgbColor? rowCellsGetBgColor(LibGhosttyHandle cells);
  int? rowCellsGetBgColorArgb(LibGhosttyHandle cells);
  RgbColor? rowCellsGetFgColor(LibGhosttyHandle cells);
  int? rowCellsGetFgColorArgb(LibGhosttyHandle cells);
  int rowCellsGetGraphemeLen(LibGhosttyHandle cells);
  List<int> rowCellsGetGraphemes(LibGhosttyHandle cells, int len);
  String rowCellsGetGraphemesUtf8(LibGhosttyHandle cells);
  bool rowCellsGetHasStyling(LibGhosttyHandle cells);

  RawCell rowCellsGetRawCell(LibGhosttyHandle cells);
  bool rowCellsGetSelected(LibGhosttyHandle cells);
  Style rowCellsGetStyle(LibGhosttyHandle cells);
  RawRowCellsSummary rowCellsGetSummary(LibGhosttyHandle cells);
  void rowCellsInit(LibGhosttyHandle cells, LibGhosttyHandle iterator);
  LibGhosttyHandle rowCellsNew();
  bool rowCellsNext(LibGhosttyHandle cells);
  void rowCellsSelect(LibGhosttyHandle cells, int x);

  bool rowGetDirty(RawRow row);
  bool rowGetGrapheme(RawRow row);
  bool rowGetHyperlink(RawRow row);
  bool rowGetKittyVirtualPlaceholder(RawRow row);

  RowSemanticPrompt rowGetSemanticPrompt(RawRow row);
  bool rowGetStyled(RawRow row);
  RawRowSummary rowGetSummary(RawRow row);
  bool rowGetWrap(RawRow row);
  bool rowGetWrapContinuation(RawRow row);

  void rowIteratorFree(LibGhosttyHandle iterator);
  bool rowIteratorGetDirty(LibGhosttyHandle iterator);
  RenderRowId rowIteratorGetId(LibGhosttyHandle iterator);
  int rowIteratorGetViewportY(LibGhosttyHandle iterator);
  RawRow rowIteratorGetRawRow(LibGhosttyHandle iterator);
  ({int startCol, int endCol})? rowIteratorGetSelection(
    LibGhosttyHandle iterator,
  );

  RawRowIteratorSummary rowIteratorGetSummary(LibGhosttyHandle iterator);
  bool rowIteratorGetRawCells(LibGhosttyHandle iterator, RawCellsView view);
  void rowIteratorInit(LibGhosttyHandle iterator, LibGhosttyHandle state);
  LibGhosttyHandle rowIteratorNew();
  bool rowIteratorNext(LibGhosttyHandle iterator);
  int? rowIteratorNextDirty(LibGhosttyHandle iterator);
  void rowIteratorSetDirty(LibGhosttyHandle iterator, {required bool dirty});

  RawGridRef terminalGridRef(
    LibGhosttyHandle terminal,
    PointTag pointTag,
    Position position,
  );
  LibGhosttyHandle terminalGridRefTrack(
    LibGhosttyHandle terminal,
    PointTag pointTag,
    Position position,
  );
  Position? terminalPointFromGridRef(
    LibGhosttyHandle terminal,
    RawGridRef ref,
    PointTag pointTag,
  );
  void trackedGridRefFree(LibGhosttyHandle ref);
  bool trackedGridRefHasValue(LibGhosttyHandle ref);
  Position? trackedGridRefPoint(LibGhosttyHandle ref, PointTag pointTag);
  void trackedGridRefSet(
    LibGhosttyHandle ref,
    LibGhosttyHandle terminal,
    PointTag pointTag,
    Position position,
  );
  RawGridRef? trackedGridRefSnapshot(LibGhosttyHandle ref);
}

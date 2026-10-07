import '../../generated/libghostty_enums.g.dart';
import '../../types/types.dart';
import '../types.dart';

abstract interface class RenderBindings {
  int cellGetCodepoint(LibGhosttyHandle cell);
  int cellGetColorPalette(LibGhosttyHandle cell);
  RgbColor cellGetColorRgb(LibGhosttyHandle cell);
  CellContentTag cellGetContentTag(LibGhosttyHandle cell);
  bool cellGetHasHyperlink(LibGhosttyHandle cell);
  bool cellGetHasStyling(LibGhosttyHandle cell);
  bool cellGetHasText(LibGhosttyHandle cell);
  bool cellGetProtected(LibGhosttyHandle cell);
  CellSemanticContent cellGetSemanticContent(LibGhosttyHandle cell);
  int cellGetStyleId(LibGhosttyHandle cell);
  RawCellSummary cellGetSummary(LibGhosttyHandle cell);
  CellWide cellGetWide(LibGhosttyHandle cell);
  bool decodeRawCell(RawCellsView view, int index, RawCellData output);

  LibGhosttyHandle gridRefCell(RawGridRef ref);
  List<int> gridRefGraphemes(RawGridRef ref);
  String? gridRefHyperlinkUri(RawGridRef ref);
  LibGhosttyHandle gridRefRow(RawGridRef ref);
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

  LibGhosttyHandle rowCellsGetRawCell(LibGhosttyHandle cells);
  bool rowCellsGetSelected(LibGhosttyHandle cells);
  Style rowCellsGetStyle(LibGhosttyHandle cells);
  RawRowCellsSummary rowCellsGetSummary(LibGhosttyHandle cells);
  void rowCellsInit(LibGhosttyHandle cells, LibGhosttyHandle iterator);
  LibGhosttyHandle rowCellsNew();
  bool rowCellsNext(LibGhosttyHandle cells);
  void rowCellsSelect(LibGhosttyHandle cells, int x);

  bool rowGetDirty(LibGhosttyHandle row);
  bool rowGetGrapheme(LibGhosttyHandle row);
  bool rowGetHyperlink(LibGhosttyHandle row);
  bool rowGetKittyVirtualPlaceholder(LibGhosttyHandle row);

  RowSemanticPrompt rowGetSemanticPrompt(LibGhosttyHandle row);
  bool rowGetStyled(LibGhosttyHandle row);
  RawRowSummary rowGetSummary(LibGhosttyHandle row);
  bool rowGetWrap(LibGhosttyHandle row);
  bool rowGetWrapContinuation(LibGhosttyHandle row);

  void rowIteratorFree(LibGhosttyHandle iterator);
  bool rowIteratorGetDirty(LibGhosttyHandle iterator);
  RenderRowId rowIteratorGetId(LibGhosttyHandle iterator);
  int rowIteratorGetViewportY(LibGhosttyHandle iterator);
  LibGhosttyHandle rowIteratorGetRawRow(LibGhosttyHandle iterator);
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

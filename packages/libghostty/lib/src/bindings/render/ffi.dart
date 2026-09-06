import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../../generated/libghostty.g.dart'
    hide
        ClipboardContent,
        ClipboardWrite,
        MouseEncoderSize,
        RenderStateCursor,
        SgrAttribute,
        String,
        Style;
import '../../generated/libghostty.g.dart'
    as native
    show RenderStateCursor, Style;
import '../../generated/libghostty_enums.g.dart';
import '../../types/types.dart';
import '../result_helpers.dart';
import '../types.dart';
import 'render.dart';

const RawRenderStateSummary _emptyRenderStateSummary = (
  cols: 0,
  rows: 0,
  dirty: .false$,
);
const _emptyRenderStateCursor = RenderStateCursor(visible: false);
const RawRowIteratorSummary _emptyRowIteratorSummary = (
  dirty: false,
  rawRow: 0,
);
const RawRowSummary _emptyRowSummary = (
  wrap: false,
  wrapContinuation: false,
  grapheme: false,
  styled: false,
  hyperlink: false,
  semanticPrompt: .none,
  kittyVirtualPlaceholder: false,
);
const _emptyTerminalColors = TerminalColors(
  foreground: RgbColor(0, 0, 0),
  background: RgbColor(0, 0, 0),
  palette: <RgbColor>[],
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
const _renderStateSummaryKeys = <RenderStateData>[.cols, .rows, .dirty];

final class FfiRenderBindings implements RenderBindings {
  final _FfiRenderRaw _raw;

  FfiRenderBindings() : _raw = _FfiRenderRaw();

  @override
  int cellGetCodepoint(LibGhosttyHandle h) =>
      _required(_raw.cellGetCodepoint(h.value), 'ghostty_cell_get');

  @override
  int cellGetColorPalette(LibGhosttyHandle h) =>
      _required(_raw.cellGetColorPalette(h.value), 'ghostty_cell_get');

  @override
  RgbColor cellGetColorRgb(LibGhosttyHandle h) =>
      _required(_raw.cellGetColorRgb(h.value), 'ghostty_cell_get');

  @override
  CellContentTag cellGetContentTag(LibGhosttyHandle h) =>
      _required(_raw.cellGetContentTag(h.value), 'ghostty_cell_get');

  @override
  bool cellGetHasHyperlink(LibGhosttyHandle h) =>
      _required(_raw.cellGetHasHyperlink(h.value), 'ghostty_cell_get');

  @override
  bool cellGetHasStyling(LibGhosttyHandle h) =>
      _required(_raw.cellGetHasStyling(h.value), 'ghostty_cell_get');

  @override
  bool cellGetHasText(LibGhosttyHandle h) =>
      _required(_raw.cellGetHasText(h.value), 'ghostty_cell_get');

  @override
  bool cellGetProtected(LibGhosttyHandle h) =>
      _required(_raw.cellGetProtected(h.value), 'ghostty_cell_get');

  @override
  CellSemanticContent cellGetSemanticContent(LibGhosttyHandle h) =>
      _required(_raw.cellGetSemanticContent(h.value), 'ghostty_cell_get');

  @override
  int cellGetStyleId(LibGhosttyHandle h) =>
      _required(_raw.cellGetStyleId(h.value), 'ghostty_cell_get');

  @override
  RawCellSummary cellGetSummary(LibGhosttyHandle h) =>
      _raw.cellGetSummary(h.value);

  @override
  CellWide cellGetWide(LibGhosttyHandle h) =>
      _required(_raw.cellGetWide(h.value), 'ghostty_cell_get');

  @override
  bool decodeRawCell(RawCellsView view, int index, RawCellData output) => false;

  @override
  LibGhosttyHandle gridRefCell(RawGridRef r) =>
      .fromAddress(_required(_raw.gridRefCell(r), 'ghostty_grid_ref_cell'));

  @override
  List<int> gridRefGraphemes(RawGridRef r) =>
      _required(_raw.gridRefGraphemes(r), 'ghostty_grid_ref_graphemes');

  @override
  String? gridRefHyperlinkUri(RawGridRef r) =>
      _optional(_raw.gridRefHyperlinkUri(r), 'ghostty_grid_ref_hyperlink_uri');

  @override
  LibGhosttyHandle gridRefRow(RawGridRef r) =>
      .fromAddress(_required(_raw.gridRefRow(r), 'ghostty_grid_ref_row'));

  @override
  Style gridRefStyle(RawGridRef r) =>
      _required(_raw.gridRefStyle(r), 'ghostty_grid_ref_style');

  @override
  void renderStateBeginUpdate(LibGhosttyHandle s, LibGhosttyHandle t) => _check(
    _raw.renderStateBeginUpdate(s.value, t.value),
    'ghostty_render_state_begin_update',
  );

  @override
  void renderStateClean(LibGhosttyHandle s) =>
      _check(_raw.renderStateClean(s.value), 'ghostty_render_state_clean');

  @override
  void renderStateEndUpdate(LibGhosttyHandle s) => _check(
    _raw.renderStateEndUpdate(s.value),
    'ghostty_render_state_end_update',
  );

  @override
  void renderStateFree(LibGhosttyHandle state) =>
      _raw.renderStateFree(state.value);

  @override
  TerminalColors renderStateGetColors(LibGhosttyHandle s) =>
      _required(_raw.renderStateGetColors(s.value), 'ghostty_render_state_get');

  @override
  int renderStateGetCols(LibGhosttyHandle s) =>
      _required(_raw.renderStateGetCols(s.value), 'ghostty_render_state_get');

  @override
  RenderStateCursor renderStateGetCursor(LibGhosttyHandle s) =>
      _required(_raw.renderStateGetCursor(s.value), 'ghostty_render_state_get');

  @override
  RenderStateDirty renderStateGetDirty(LibGhosttyHandle s) =>
      _required(_raw.renderStateGetDirty(s.value), 'ghostty_render_state_get');

  @override
  int renderStateGetRows(LibGhosttyHandle s) =>
      _required(_raw.renderStateGetRows(s.value), 'ghostty_render_state_get');

  @override
  RawRenderStateSummary renderStateGetSummary(LibGhosttyHandle s) => _required(
    _raw.renderStateGetSummary(s.value),
    'ghostty_render_state_get_multi',
  );

  @override
  LibGhosttyHandle renderStateNew() => .fromAddress(
    _required(_raw.renderStateNew(), 'ghostty_render_state_new'),
  );

  @override
  void renderStateSetDirty(LibGhosttyHandle s, RenderStateDirty d) =>
      _check(_raw.renderStateSetDirty(s.value, d), 'ghostty_render_state_set');

  @override
  void renderStateUpdate(LibGhosttyHandle s, LibGhosttyHandle t) => _check(
    _raw.renderStateUpdate(s.value, t.value),
    'ghostty_render_state_update',
  );

  @override
  void rowCellsFree(LibGhosttyHandle h) => _raw.rowCellsFree(h.value);

  @override
  RgbColor? rowCellsGetBgColor(LibGhosttyHandle h) => _optionalColor(
    _raw.rowCellsGetBgColor(h.value),
    'ghostty_render_state_row_cells_get',
  );

  @override
  int? rowCellsGetBgColorArgb(LibGhosttyHandle h) => _optionalColor(
    _raw.rowCellsGetBgColorArgb(h.value),
    'ghostty_render_state_row_cells_get',
  );

  @override
  RgbColor? rowCellsGetFgColor(LibGhosttyHandle h) => _optionalColor(
    _raw.rowCellsGetFgColor(h.value),
    'ghostty_render_state_row_cells_get',
  );

  @override
  int? rowCellsGetFgColorArgb(LibGhosttyHandle h) => _optionalColor(
    _raw.rowCellsGetFgColorArgb(h.value),
    'ghostty_render_state_row_cells_get',
  );

  @override
  int rowCellsGetGraphemeLen(LibGhosttyHandle h) => _required(
    _raw.rowCellsGetGraphemeLen(h.value),
    'ghostty_render_state_row_cells_get',
  );

  @override
  List<int> rowCellsGetGraphemes(LibGhosttyHandle h, int len) => _required(
    _raw.rowCellsGetGraphemes(h.value, len),
    'ghostty_render_state_row_cells_get',
  );

  @override
  String rowCellsGetGraphemesUtf8(LibGhosttyHandle h) => _required(
    _raw.rowCellsGetGraphemesUtf8(h.value),
    'ghostty_render_state_row_cells_get',
  );

  @override
  bool rowCellsGetHasStyling(LibGhosttyHandle h) => _required(
    _raw.rowCellsGetHasStyling(h.value),
    'ghostty_render_state_row_cells_get',
  );

  @override
  LibGhosttyHandle rowCellsGetRawCell(LibGhosttyHandle h) => .fromAddress(
    _required(
      _raw.rowCellsGetRawCell(h.value),
      'ghostty_render_state_row_cells_get',
    ),
  );

  @override
  bool rowCellsGetSelected(LibGhosttyHandle h) => _required(
    _raw.rowCellsGetSelected(h.value),
    'ghostty_render_state_row_cells_get',
  );

  @override
  Style rowCellsGetStyle(LibGhosttyHandle h) => _required(
    _raw.rowCellsGetStyle(h.value),
    'ghostty_render_state_row_cells_get',
  );

  @override
  RawRowCellsSummary rowCellsGetSummary(LibGhosttyHandle h) =>
      _raw.rowCellsGetSummary(h.value);

  @override
  void rowCellsInit(LibGhosttyHandle h, LibGhosttyHandle i) => _check(
    _raw.rowCellsInit(h.value, i.value),
    'ghostty_render_state_row_get',
  );

  @override
  LibGhosttyHandle rowCellsNew() => .fromAddress(
    _required(_raw.rowCellsNew(), 'ghostty_render_state_row_cells_new'),
  );

  @override
  bool rowCellsNext(LibGhosttyHandle h) => _raw.rowCellsNext(h.value);

  @override
  void rowCellsSelect(LibGhosttyHandle h, int x) => _check(
    _raw.rowCellsSelect(h.value, x),
    'ghostty_render_state_row_cells_select',
  );

  @override
  bool rowGetDirty(LibGhosttyHandle h) =>
      _required(_raw.rowGetDirty(h.value), 'ghostty_row_get');

  @override
  bool rowGetGrapheme(LibGhosttyHandle h) =>
      _required(_raw.rowGetGrapheme(h.value), 'ghostty_row_get');

  @override
  bool rowGetHyperlink(LibGhosttyHandle h) =>
      _required(_raw.rowGetHyperlink(h.value), 'ghostty_row_get');

  @override
  bool rowGetKittyVirtualPlaceholder(LibGhosttyHandle h) =>
      _required(_raw.rowGetKittyVirtualPlaceholder(h.value), 'ghostty_row_get');

  @override
  RowSemanticPrompt rowGetSemanticPrompt(LibGhosttyHandle h) =>
      _required(_raw.rowGetSemanticPrompt(h.value), 'ghostty_row_get');

  @override
  bool rowGetStyled(LibGhosttyHandle h) =>
      _required(_raw.rowGetStyled(h.value), 'ghostty_row_get');

  @override
  RawRowSummary rowGetSummary(LibGhosttyHandle h) =>
      _required(_raw.rowGetSummary(h.value), 'ghostty_row_get_multi');

  @override
  bool rowGetWrap(LibGhosttyHandle h) =>
      _required(_raw.rowGetWrap(h.value), 'ghostty_row_get');

  @override
  bool rowGetWrapContinuation(LibGhosttyHandle h) =>
      _required(_raw.rowGetWrapContinuation(h.value), 'ghostty_row_get');

  @override
  void rowIteratorFree(LibGhosttyHandle h) => _raw.rowIteratorFree(h.value);

  @override
  bool rowIteratorGetDirty(LibGhosttyHandle h) => _required(
    _raw.rowIteratorGetDirty(h.value),
    'ghostty_render_state_row_get',
  );

  @override
  LibGhosttyHandle rowIteratorGetRawRow(LibGhosttyHandle h) => .fromAddress(
    _required(
      _raw.rowIteratorGetRawRow(h.value),
      'ghostty_render_state_row_get',
    ),
  );

  @override
  ({int startCol, int endCol})? rowIteratorGetSelection(LibGhosttyHandle h) =>
      _optional(
        _raw.rowIteratorGetSelection(h.value),
        'ghostty_render_state_row_get',
      );

  @override
  RawRowIteratorSummary rowIteratorGetSummary(LibGhosttyHandle h) => _required(
    _raw.rowIteratorGetSummary(h.value),
    'ghostty_render_state_row_get_multi',
  );

  @override
  bool rowIteratorGetRawCells(LibGhosttyHandle h, RawCellsView view) =>
      _raw.rowIteratorGetRawCells(h.value, view);

  @override
  void rowIteratorInit(LibGhosttyHandle h, LibGhosttyHandle s) => _check(
    _raw.rowIteratorInit(h.value, s.value),
    'ghostty_render_state_get',
  );

  @override
  LibGhosttyHandle rowIteratorNew() => .fromAddress(
    _required(_raw.rowIteratorNew(), 'ghostty_render_state_row_iterator_new'),
  );

  @override
  bool rowIteratorNext(LibGhosttyHandle h) => _raw.rowIteratorNext(h.value);

  @override
  int? rowIteratorNextDirty(LibGhosttyHandle h) =>
      _raw.rowIteratorNextDirty(h.value);

  @override
  void rowIteratorSetDirty(LibGhosttyHandle h, {required bool dirty}) => _check(
    _raw.rowIteratorSetDirty(h.value, dirty: dirty),
    'ghostty_render_state_row_set',
  );

  @override
  RawGridRef terminalGridRef(LibGhosttyHandle t, PointTag p, Position v) =>
      _required(
        _raw.terminalGridRef(t.value, p, v),
        'ghostty_terminal_grid_ref',
      );

  @override
  LibGhosttyHandle terminalGridRefTrack(
    LibGhosttyHandle t,
    PointTag p,
    Position v,
  ) => .fromAddress(
    _required(
      _raw.terminalGridRefTrack(t.value, p, v),
      'ghostty_terminal_grid_ref_track',
    ),
  );

  @override
  Position? terminalPointFromGridRef(
    LibGhosttyHandle t,
    RawGridRef r,
    PointTag p,
  ) => _optional(
    _raw.terminalPointFromGridRef(t.value, r, p),
    'ghostty_terminal_point_from_grid_ref',
  );

  @override
  void trackedGridRefFree(LibGhosttyHandle r) =>
      _raw.trackedGridRefFree(r.value);

  @override
  bool trackedGridRefHasValue(LibGhosttyHandle r) =>
      _raw.trackedGridRefHasValue(r.value);

  @override
  Position? trackedGridRefPoint(LibGhosttyHandle r, PointTag p) => _optional(
    _raw.trackedGridRefPoint(r.value, p),
    'ghostty_tracked_grid_ref_point',
  );

  @override
  void trackedGridRefSet(
    LibGhosttyHandle r,
    LibGhosttyHandle t,
    PointTag p,
    Position v,
  ) => _check(
    _raw.trackedGridRefSet(r.value, t.value, p, v),
    'ghostty_tracked_grid_ref_set',
  );

  @override
  RawGridRef? trackedGridRefSnapshot(LibGhosttyHandle r) => _optional(
    _raw.trackedGridRefSnapshot(r.value),
    'ghostty_tracked_grid_ref_snapshot',
  );

  void _check(Result code, String operation) =>
      checkResultCode(code.value, operation: operation);

  T? _optional<T>(CResult<T> result, String operation) {
    if (result.$1 == .noValue) return null;
    _check(result.$1, operation);
    return result.$2;
  }

  T? _optionalColor<T>(CResult<T> result, String operation) {
    if (result.$1 == .noValue || result.$1 == .invalidValue) {
      return null;
    }
    _check(result.$1, operation);
    return result.$2;
  }

  T _required<T>(CResult<T> result, String operation) {
    checkRequiredCode(result.$1.value, operation: operation);
    return result.$2;
  }
}

final class _FfiRenderRaw {
  final _outU8 = calloc<Uint8>();
  final _outU16 = calloc<Uint16>();
  final _outU32 = calloc<Uint32>();
  final _outU64 = calloc<Uint64>();
  final _outI32 = calloc<Int32>();
  final _outBool = calloc<Bool>();
  final _outStyle = calloc<native.Style>();
  final _outColors = calloc<RenderStateColors>();
  final _outCursor = calloc<native.RenderStateCursor>();
  final _outSize = calloc<Size>();
  final _outColorRgb = calloc<ColorRgb>();
  final _graphemeBuf = calloc<Uint32>(32);
  final _multiKeys = calloc<UnsignedInt>(12);
  final _multiValues = calloc<Pointer<Void>>(12);
  final _multiOut = calloc<Uint64>(12);
  final _renderStateSummaryMultiKeys = calloc<UnsignedInt>(
    _renderStateSummaryKeys.length,
  );
  final _renderStateSummaryMultiValues = calloc<Pointer<Void>>(
    _renderStateSummaryKeys.length,
  );
  final _renderStateSummaryMultiOut = calloc<Uint64>(
    _renderStateSummaryKeys.length,
  );
  final _rowCellsMultiKeys = calloc<UnsignedInt>(_rowCellsSummaryKeys.length);
  final _rowCellsMultiValues = calloc<Pointer<Void>>(
    _rowCellsSummaryKeys.length,
  );
  final _rowCellsMultiOut = calloc<Uint64>(_rowCellsSummaryKeys.length);
  final _cellMultiKeys = calloc<UnsignedInt>(_cellSummaryKeys.length);
  final _cellMultiValues = calloc<Pointer<Void>>(_cellSummaryKeys.length);
  final _cellMultiOut = calloc<Uint64>(_cellSummaryKeys.length);

  _FfiRenderRaw() {
    _outColors.ref.size = sizeOf<RenderStateColors>();
    _outCursor.ref.size = sizeOf<native.RenderStateCursor>();
    _outStyle.ref.size = sizeOf<native.Style>();
    for (var i = 0; i < _renderStateSummaryKeys.length; i++) {
      _renderStateSummaryMultiKeys[i] = _renderStateSummaryKeys[i].value;
      _renderStateSummaryMultiValues[i] = (_renderStateSummaryMultiOut + i)
          .cast();
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

  CResult<int> cellGetCodepoint(int cell) => _cellGetU32(cell, .codepoint);

  CResult<int> cellGetColorPalette(int cell) {
    final result = ghostty_cell_get(cell, .colorPalette, _outU8.cast());
    if (result != .success) return (result, 0);
    return (result, _outU8.value);
  }

  CResult<RgbColor> cellGetColorRgb(int cell) {
    return using((arena) {
      final out = arena<ColorRgb>();
      final result = ghostty_cell_get(cell, .colorRgb, out.cast());
      if (result != .success) return (result, const RgbColor(0, 0, 0));
      return (result, RgbColor(out.ref.r, out.ref.g, out.ref.b));
    });
  }

  CResult<CellContentTag> cellGetContentTag(int cell) {
    final raw = _cellGetI32(cell, .contentTag);
    return (raw.$1, .fromValue(raw.$2));
  }

  CResult<bool> cellGetHasHyperlink(int cell) {
    return _cellGetBool(cell, .hasHyperlink);
  }

  CResult<bool> cellGetHasStyling(int cell) => _cellGetBool(cell, .hasStyling);

  CResult<bool> cellGetHasText(int cell) => _cellGetBool(cell, .hasText);

  CResult<bool> cellGetProtected(int cell) => _cellGetBool(cell, .protected);

  CResult<CellSemanticContent> cellGetSemanticContent(int cell) {
    final raw = _cellGetI32(cell, .semanticContent);
    return (raw.$1, .fromValue(raw.$2));
  }

  CResult<int> cellGetStyleId(int cell) {
    final result = ghostty_cell_get(cell, .styleId, _outU16.cast());
    if (result != .success) return (result, 0);
    return (result, _outU16.value);
  }

  RawCellSummary cellGetSummary(int cell) {
    final result = ghostty_cell_get_multi(
      cell,
      _cellSummaryKeys.length,
      _cellMultiKeys,
      _cellMultiValues,
      _outSize,
    );
    checkRequiredCode(result.value, operation: 'ghostty_cell_get_multi');
    return (
      codepoint: (_cellMultiOut + 0).cast<Uint32>().value,
      styleId: (_cellMultiOut + 1).cast<Uint16>().value,
      wide: .fromValue((_cellMultiOut + 2).cast<Int32>().value),
    );
  }

  CResult<CellWide> cellGetWide(int cell) {
    final raw = _cellGetI32(cell, .wide);
    return (raw.$1, .fromValue(raw.$2));
  }

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
      if (result != .success) return (result, 0);
      return (result, _outU64.value);
    });
  }

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

      if (result == .outOfSpace) {
        final bigBuf = arena<Uint32>(len);
        result = ghostty_grid_ref_graphemes(gridRef, bigBuf, len, outLen);
        len = outLen.value;
        return (result, [for (var i = 0; i < len; i++) bigBuf[i]]);
      }

      if (result != .success) return (result, const []);

      return (result, [for (var i = 0; i < len; i++) _graphemeBuf[i]]);
    });
  }

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

      if (result == .outOfSpace) {
        buf = arena<Uint8>(len);
        result = ghostty_grid_ref_hyperlink_uri(gridRef, buf, len, outLen);
        len = outLen.value;
      }

      if (result != .success) return (result, '');
      if (len == 0) return (result, '');
      return (result, utf8.decode(buf.asTypedList(len)));
    });
  }

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
      if (result != .success) return (result, 0);
      return (result, _outU64.value);
    });
  }

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
      if (result != .success) return (result, const Style());
      return (result, _readNativeStyle(_outStyle.ref));
    });
  }

  Result renderStateBeginUpdate(int state, int terminal) {
    return ghostty_render_state_begin_update(
      Pointer.fromAddress(state),
      Pointer.fromAddress(terminal),
    );
  }

  Result renderStateClean(int state) {
    return ghostty_render_state_clean(Pointer.fromAddress(state));
  }

  Result renderStateEndUpdate(int state) {
    return ghostty_render_state_end_update(Pointer.fromAddress(state));
  }

  void renderStateFree(int handle) {
    ghostty_render_state_free(Pointer.fromAddress(handle));
  }

  CResult<TerminalColors> renderStateGetColors(int state) {
    final result = ghostty_render_state_get(
      Pointer.fromAddress(state),
      .colors,
      _outColors.cast(),
    );
    if (result != .success) return (result, _emptyTerminalColors);

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

  CResult<int> renderStateGetCols(int state) {
    return _renderStateGetU16(state, .cols);
  }

  CResult<RenderStateCursor> renderStateGetCursor(int state) {
    final result = ghostty_render_state_get(
      Pointer.fromAddress(state),
      .cursor,
      _outCursor.cast(),
    );
    if (result != .success) {
      return (result, _emptyRenderStateCursor);
    }
    final ref = _outCursor.ref;
    return (
      result,
      RenderStateCursor(
        viewportHasValue: ref.viewport_has_value,
        viewportX: ref.viewport_has_value ? ref.viewport_x : 0,
        viewportY: ref.viewport_has_value ? ref.viewport_y : 0,
        wideTail: ref.viewport_has_value && ref.wide_tail,
        visible: ref.visible,
        blinking: ref.blinking,
        passwordInput: ref.password_input,
        visualStyle: ref.visual_style,
      ),
    );
  }

  CResult<RenderStateDirty> renderStateGetDirty(int state) {
    final result = ghostty_render_state_get(
      Pointer.fromAddress(state),
      .dirty,
      _outI32.cast(),
    );
    if (result != .success) return (result, .false$);
    return (result, .fromValue(_outI32.value));
  }

  CResult<int> renderStateGetRows(int state) {
    return _renderStateGetU16(state, .rows);
  }

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

  CResult<int> renderStateNew() {
    return using((arena) {
      final ptr = arena<Pointer<RenderStateImpl>>();
      final result = ghostty_render_state_new(nullptr, ptr);
      return (result, ptr.value.address);
    });
  }

  Result renderStateSetDirty(int state, RenderStateDirty dirty) {
    _outI32.value = dirty.value;
    return ghostty_render_state_set(
      Pointer.fromAddress(state),
      .dirty,
      _outI32.cast(),
    );
  }

  Result renderStateUpdate(int state, int terminal) {
    return ghostty_render_state_update(
      Pointer.fromAddress(state),
      Pointer.fromAddress(terminal),
    );
  }

  void rowCellsFree(int handle) {
    ghostty_render_state_row_cells_free(Pointer.fromAddress(handle));
  }

  CResult<RgbColor> rowCellsGetBgColor(int cells) {
    final result = ghostty_render_state_row_cells_get(
      Pointer.fromAddress(cells),
      .bgColor,
      _outColorRgb.cast(),
    );
    if (result != .success) return (result, const RgbColor(0, 0, 0));
    return (
      result,
      RgbColor(_outColorRgb.ref.r, _outColorRgb.ref.g, _outColorRgb.ref.b),
    );
  }

  CResult<int> rowCellsGetBgColorArgb(int cells) {
    final result = ghostty_render_state_row_cells_get(
      Pointer.fromAddress(cells),
      .bgColor,
      _outColorRgb.cast(),
    );
    if (result != .success) return (result, 0);
    final color = _outColorRgb.ref;
    return (result, 0xFF000000 | (color.r << 16) | (color.g << 8) | color.b);
  }

  CResult<RgbColor> rowCellsGetFgColor(int cells) {
    final result = ghostty_render_state_row_cells_get(
      Pointer.fromAddress(cells),
      .fgColor,
      _outColorRgb.cast(),
    );
    if (result != .success) return (result, const RgbColor(0, 0, 0));
    return (
      result,
      RgbColor(_outColorRgb.ref.r, _outColorRgb.ref.g, _outColorRgb.ref.b),
    );
  }

  CResult<int> rowCellsGetFgColorArgb(int cells) {
    final result = ghostty_render_state_row_cells_get(
      Pointer.fromAddress(cells),
      .fgColor,
      _outColorRgb.cast(),
    );
    if (result != .success) return (result, 0);
    final color = _outColorRgb.ref;
    return (result, 0xFF000000 | (color.r << 16) | (color.g << 8) | color.b);
  }

  CResult<int> rowCellsGetGraphemeLen(int cells) {
    final result = ghostty_render_state_row_cells_get(
      Pointer.fromAddress(cells),
      .graphemesLen,
      _outU32.cast(),
    );
    if (result != .success) return (result, 0);
    return (result, _outU32.value);
  }

  CResult<List<int>> rowCellsGetGraphemes(int cells, int len) {
    if (len <= 0) return (.success, const []);
    final buf = len <= 32 ? _graphemeBuf : calloc<Uint32>(len);
    final result = ghostty_render_state_row_cells_get(
      Pointer.fromAddress(cells),
      .graphemesBuf,
      buf.cast(),
    );
    if (result != .success) {
      if (len > 32) calloc.free(buf);
      return (result, const []);
    }
    final graphemes = [for (var i = 0; i < len; i++) buf[i]];
    if (len > 32) calloc.free(buf);
    return (result, graphemes);
  }

  CResult<String> rowCellsGetGraphemesUtf8(int cells) {
    return using((arena) {
      const inlineCap = 64;
      var data = arena<Uint8>(inlineCap);
      final buffer = Buffer.$allocate(arena, ptr: data, cap: inlineCap, len: 0);

      var result = ghostty_render_state_row_cells_get(
        Pointer.fromAddress(cells),
        .graphemesUtf8,
        buffer.cast(),
      );
      var len = buffer.ref.len;

      if (result == .outOfSpace) {
        data = arena<Uint8>(len);
        buffer.ref
          ..ptr = data
          ..cap = len
          ..len = 0;
        result = ghostty_render_state_row_cells_get(
          Pointer.fromAddress(cells),
          .graphemesUtf8,
          buffer.cast(),
        );
        len = buffer.ref.len;
      }

      if (result != .success) return (result, '');

      return (result, len == 0 ? '' : utf8.decode(data.asTypedList(len)));
    });
  }

  CResult<bool> rowCellsGetHasStyling(int cells) {
    final result = ghostty_render_state_row_cells_get(
      Pointer.fromAddress(cells),
      .hasStyling,
      _outBool.cast(),
    );
    if (result != .success) return (result, false);
    return (result, _outBool.value);
  }

  CResult<int> rowCellsGetRawCell(int cells) {
    final result = ghostty_render_state_row_cells_get(
      Pointer.fromAddress(cells),
      .raw,
      _outU64.cast(),
    );
    if (result != .success) return (result, 0);
    return (result, _outU64.value);
  }

  CResult<bool> rowCellsGetSelected(int cells) {
    final result = ghostty_render_state_row_cells_get(
      Pointer.fromAddress(cells),
      .selected,
      _outBool.cast(),
    );
    if (result != .success) return (result, false);
    return (result, _outBool.value);
  }

  CResult<Style> rowCellsGetStyle(int cells) {
    final result = ghostty_render_state_row_cells_get(
      Pointer.fromAddress(cells),
      .style,
      _outStyle.cast(),
    );
    if (result != .success) return (result, const Style());
    return (result, _readNativeStyle(_outStyle.ref));
  }

  RawRowCellsSummary rowCellsGetSummary(int cells) {
    final result = ghostty_render_state_row_cells_get_multi(
      Pointer.fromAddress(cells),
      _rowCellsSummaryKeys.length,
      _rowCellsMultiKeys,
      _rowCellsMultiValues,
      _outSize,
    );
    checkRequiredCode(
      result.value,
      operation: 'ghostty_render_state_row_cells_get_multi',
    );
    return (
      rawCell: (_rowCellsMultiOut + 0).value,
      graphemeLen: (_rowCellsMultiOut + 1).cast<Uint32>().value,
      selected: (_rowCellsMultiOut + 2).cast<Bool>().value,
    );
  }

  Result rowCellsInit(int cells, int iterator) {
    return using((arena) {
      final ptr = arena<Pointer<RenderStateRowCells>>();
      ptr.value = Pointer.fromAddress(cells);
      return ghostty_render_state_row_get(
        Pointer.fromAddress(iterator),
        .cells,
        ptr.cast(),
      );
    });
  }

  CResult<int> rowCellsNew() {
    return using((arena) {
      final ptr = arena<Pointer<RenderStateRowCellsImpl>>();
      final result = ghostty_render_state_row_cells_new(nullptr, ptr);
      return (result, ptr.value.address);
    });
  }

  bool rowCellsNext(int cells) {
    return ghostty_render_state_row_cells_next(Pointer.fromAddress(cells));
  }

  Result rowCellsSelect(int cells, int x) {
    return ghostty_render_state_row_cells_select(Pointer.fromAddress(cells), x);
  }

  CResult<bool> rowGetDirty(int row) => _rowGetBool(row, .dirty);

  CResult<bool> rowGetGrapheme(int row) => _rowGetBool(row, .grapheme);

  CResult<bool> rowGetHyperlink(int row) => _rowGetBool(row, .hyperlink);

  CResult<bool> rowGetKittyVirtualPlaceholder(int row) {
    return _rowGetBool(row, .kittyVirtualPlaceholder);
  }

  CResult<RowSemanticPrompt> rowGetSemanticPrompt(int row) {
    final result = ghostty_row_get(row, .semanticPrompt, _outI32.cast());
    if (result != .success) return (result, .none);
    return (result, .fromValue(_outI32.value));
  }

  CResult<bool> rowGetStyled(int row) => _rowGetBool(row, .styled);

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
    if (result != .success) return (result, _emptyRowSummary);
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

  CResult<bool> rowGetWrap(int row) => _rowGetBool(row, .wrap);

  CResult<bool> rowGetWrapContinuation(int row) {
    return _rowGetBool(row, .wrapContinuation);
  }

  void rowIteratorFree(int handle) {
    ghostty_render_state_row_iterator_free(Pointer.fromAddress(handle));
  }

  CResult<bool> rowIteratorGetDirty(int iterator) {
    final result = ghostty_render_state_row_get(
      Pointer.fromAddress(iterator),
      .dirty,
      _outBool.cast(),
    );
    if (result != .success) return (result, false);
    return (result, _outBool.value);
  }

  CResult<int> rowIteratorGetRawRow(int iterator) {
    final result = ghostty_render_state_row_get(
      Pointer.fromAddress(iterator),
      .raw,
      _outU64.cast(),
    );
    if (result != .success) return (result, 0);
    return (result, _outU64.value);
  }

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
        .selection,
        selection.cast(),
      );
      if (result == .noValue) return (result, (startCol: 0, endCol: 0));
      if (result != .success) return (result, (startCol: 0, endCol: 0));
      return (
        result,
        (startCol: selection.ref.start_x, endCol: selection.ref.end_x),
      );
    });
  }

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
    if (result != .success) return (result, _emptyRowIteratorSummary);
    return (
      result,
      (
        dirty: (_multiOut + 0).cast<Bool>().value,
        rawRow: (_multiOut + 1).value,
      ),
    );
  }

  bool rowIteratorGetRawCells(int iterator, RawCellsView view) {
    view.clear();
    return false;
  }

  Result rowIteratorInit(int iterator, int renderState) {
    return using((arena) {
      final ptr = arena<Pointer<RenderStateRowIterator>>();
      ptr.value = Pointer.fromAddress(iterator);
      return ghostty_render_state_get(
        Pointer.fromAddress(renderState),
        .rowIterator,
        ptr.cast(),
      );
    });
  }

  CResult<int> rowIteratorNew() {
    return using((arena) {
      final ptr = arena<Pointer<RenderStateRowIteratorImpl>>();
      final result = ghostty_render_state_row_iterator_new(nullptr, ptr);
      return (result, ptr.value.address);
    });
  }

  bool rowIteratorNext(int iterator) {
    return ghostty_render_state_row_iterator_next(
      Pointer.fromAddress(iterator),
    );
  }

  int? rowIteratorNextDirty(int iterator) {
    return using((arena) {
      final outY = arena<Uint16>();
      final hasNext = ghostty_render_state_row_iterator_next_dirty(
        Pointer.fromAddress(iterator),
        outY,
      );
      return hasNext ? outY.value : null;
    });
  }

  Result rowIteratorSetDirty(int iterator, {required bool dirty}) {
    _outBool.value = dirty;
    return ghostty_render_state_row_set(
      Pointer.fromAddress(iterator),
      .dirty,
      _outBool.cast(),
    );
  }

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
      if (result != .success) return (result, (node: 0, x: 0, y: 0));
      return (result, _readGridRef(gridRef.ref));
    });
  }

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
      if (result != .success) return (result, const Position(row: 0, col: 0));
      return (result, Position(row: out.ref.y, col: out.ref.x));
    });
  }

  void trackedGridRefFree(int ref) {
    ghostty_tracked_grid_ref_free(Pointer.fromAddress(ref));
  }

  bool trackedGridRefHasValue(int ref) {
    return ghostty_tracked_grid_ref_has_value(Pointer.fromAddress(ref));
  }

  CResult<Position> trackedGridRefPoint(int ref, PointTag pointTag) {
    return using((arena) {
      final out = arena<PointCoordinate>();
      final result = ghostty_tracked_grid_ref_point(
        Pointer.fromAddress(ref),
        pointTag,
        out,
      );
      if (result != .success) return (result, const Position(row: 0, col: 0));
      return (result, Position(row: out.ref.y, col: out.ref.x));
    });
  }

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

  CResult<RawGridRef> trackedGridRefSnapshot(int ref) {
    return using((arena) {
      final gridRef = arena<GridRef>();
      gridRef.ref.size = sizeOf<GridRef>();
      final result = ghostty_tracked_grid_ref_snapshot(
        Pointer.fromAddress(ref),
        gridRef,
      );
      if (result != .success) return (result, (node: 0, x: 0, y: 0));
      return (result, _readGridRef(gridRef.ref));
    });
  }

  CResult<bool> _cellGetBool(int cell, CellData data) {
    final result = ghostty_cell_get(cell, data, _outBool.cast());
    if (result != .success) return (result, false);
    return (result, _outBool.value);
  }

  CResult<int> _cellGetI32(int cell, CellData data) {
    final result = ghostty_cell_get(cell, data, _outI32.cast());
    if (result != .success) return (result, 0);
    return (result, _outI32.value);
  }

  CResult<int> _cellGetU32(int cell, CellData data) {
    final result = ghostty_cell_get(cell, data, _outU32.cast());
    if (result != .success) return (result, 0);
    return (result, _outU32.value);
  }

  CResult<int> _renderStateGetU16(int state, RenderStateData data) {
    final result = ghostty_render_state_get(
      Pointer.fromAddress(state),
      data,
      _outU16.cast(),
    );
    if (result != .success) return (result, 0);
    return (result, _outU16.value);
  }

  CResult<bool> _rowGetBool(int row, RowData data) {
    final result = ghostty_row_get(row, data, _outBool.cast());
    if (result != .success) return (result, false);
    return (result, _outBool.value);
  }

  static RawGridRef _readGridRef(GridRef ref) {
    return (node: ref.node.address, x: ref.x, y: ref.y);
  }

  static RawColor _readNativeColor(StyleColor c) => (
    tag: .fromValue(c.tag.value),
    palette: c.value.palette,
    r: c.value.rgb.r,
    g: c.value.rgb.g,
    b: c.value.rgb.b,
  );

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
      underline: .fromValue(s.underline),
    );
  }

  static void _writePoint(Point target, PointTag pointTag, Position position) {
    target.tagAsInt = pointTag.value;
    target.value.coordinate.x = position.col;
    target.value.coordinate.y = position.row;
  }
}

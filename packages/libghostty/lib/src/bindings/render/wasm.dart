import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import '../../generated/libghostty_enums.g.dart';
import '../../generated/libghostty_wasm.g.dart';
import '../../types/types.dart';
import '../result_helpers.dart';
import '../types.dart';
import '../wasm/allocator.dart';
import '../wasm/layouts.dart';
import '../wasm/memory.dart';
import '../wasm/scratch.dart';
import 'render.dart';

const _wasmEnumSize = 4;
const _wasmPointerSize = 4;
const _wasmSizeSize = 4;
const _wasmOutputSlotSize = 8;
const _maxMultiQueryCount = 12;
final JSString _cellGetMultiMethod = 'ghostty_cell_get_multi'.toJS;
final JSString _rowGetMultiMethod = 'ghostty_row_get_multi'.toJS;
const _emptyRenderStateCursor = RenderStateCursor(visible: false);
const RawRowIteratorSummary _emptyRowIteratorSummary = (
  dirty: false,
  rawRow: 0,
);
const RawRowCellsSummary _emptyRowCellsSummary = (
  rawCell: 0,
  graphemeLen: 0,
  selected: false,
);
const RawCellSummary _emptyCellSummary = (
  codepoint: 0,
  styleId: 0,
  wide: .narrow,
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
  palette: [],
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

final class WasmRenderBindings implements RenderBindings {
  final _WasmRenderRaw _raw;

  WasmRenderBindings(GhosttyExports exports, Layouts layout)
    : _raw = _WasmRenderRaw(exports, layout);

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
      _required(_raw.cellGetSummary(h.value), 'ghostty_cell_get_multi');

  @override
  CellWide cellGetWide(LibGhosttyHandle h) =>
      _required(_raw.cellGetWide(h.value), 'ghostty_cell_get');

  @override
  bool decodeRawCell(RawCellsView view, int index, RawCellData output) =>
      _raw.decodeRawCell(view, index, output);

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
  RawRenderStateSummary renderStateGetSummary(LibGhosttyHandle s) =>
      _raw.renderStateGetSummary(s.value);

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
  RawRowCellsSummary rowCellsGetSummary(LibGhosttyHandle h) => _required(
    _raw.rowCellsGetSummary(h.value),
    'ghostty_render_state_row_cells_get_multi',
  );

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
    if (result.$1 == Result.noValue) return null;
    _check(result.$1, operation);
    return result.$2;
  }

  T? _optionalColor<T>(CResult<T> result, String operation) {
    if (result.$1 == Result.noValue || result.$1 == Result.invalidValue) {
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

final class _WasmRenderRaw {
  static final _jsBigInt = globalContext['BigInt']! as JSFunction;
  final GhosttyExports _exports;
  final Memory _memory;
  final Layouts _layout;
  final WasmScratchPool _scratch;
  final _cellGetMultiArguments = List<JSAny?>.filled(5, null);
  final _rowGetMultiArguments = List<JSAny?>.filled(5, null);
  late final int _multiKeys;
  late final int _multiValues;
  late final int _multiOut;
  late final int _multiWritten;
  late final int _renderStateSummaryMultiKeys;
  late final int _renderStateSummaryMultiValues;
  late final int _renderStateSummaryMultiOut;
  late final int _rowCellsMultiKeys;
  late final int _rowCellsMultiValues;
  late final int _rowCellsMultiOut;
  late final int _cellMultiKeys;
  late final int _cellMultiValues;

  late final int _cellMultiOut;

  _WasmRenderRaw(this._exports, this._layout)
    : _memory = Memory(_exports),
      _scratch = WasmScratchPool(
        WasmExportScratchAllocator(_exports),
        maxVariableLength: WasmScratchPool.defaultMaxVariableLength,
      ) {
    _multiKeys = _allocateBytes(_maxMultiQueryCount * _wasmEnumSize);
    _multiValues = _allocateBytes(_maxMultiQueryCount * _wasmPointerSize);
    _multiOut = _allocateBytes(_maxMultiQueryCount * _wasmOutputSlotSize);
    _multiWritten = _allocateSize();
    _renderStateSummaryMultiKeys = _allocateBytes(
      _renderStateSummaryKeys.length * _wasmEnumSize,
    );
    _renderStateSummaryMultiValues = _allocateBytes(
      _renderStateSummaryKeys.length * _wasmPointerSize,
    );
    _renderStateSummaryMultiOut = _allocateBytes(
      _renderStateSummaryKeys.length * _wasmOutputSlotSize,
    );
    _rowCellsMultiKeys = _allocateBytes(
      _rowCellsSummaryKeys.length * _wasmEnumSize,
    );
    _rowCellsMultiValues = _allocateBytes(
      _rowCellsSummaryKeys.length * _wasmPointerSize,
    );
    _rowCellsMultiOut = _allocateBytes(
      _rowCellsSummaryKeys.length * _wasmOutputSlotSize,
    );
    _cellMultiKeys = _allocateBytes(_cellSummaryKeys.length * _wasmEnumSize);
    _cellMultiValues = _allocateBytes(
      _cellSummaryKeys.length * _wasmPointerSize,
    );
    _cellMultiOut = _allocateBytes(
      _cellSummaryKeys.length * _wasmOutputSlotSize,
    );
    _writeMultiKeys(
      _renderStateSummaryKeys,
      _renderStateSummaryMultiKeys,
      _renderStateSummaryMultiValues,
      _renderStateSummaryMultiOut,
    );
    _writeMultiKeys(
      _rowCellsSummaryKeys,
      _rowCellsMultiKeys,
      _rowCellsMultiValues,
      _rowCellsMultiOut,
    );
    _writeMultiKeys(
      _cellSummaryKeys,
      _cellMultiKeys,
      _cellMultiValues,
      _cellMultiOut,
    );
  }

  CResult<int> cellGetCodepoint(int cell) => _cellGetU32(cell, .codepoint);

  CResult<int> cellGetColorPalette(int cell) {
    final frame = _scratch.acquire(const []);
    try {
      final outPtr = frame.variableAddress(0, 1);
      final result = Result.fromValue(
        _callCellGet(cell, .colorPalette, outPtr),
      );
      if (result != .success) return (result, 0);
      return (result, _memory.readU8(outPtr));
    } finally {
      frame.release();
    }
  }

  CResult<RgbColor> cellGetColorRgb(int cell) {
    final frame = _scratch.acquire(const []);
    try {
      final outPtr = frame.variableAddress(0, _layout.colorRgbSize);
      final result = Result.fromValue(
        _callCellGet(cell, CellData.colorRgb, outPtr),
      );
      if (result != .success) return (result, const RgbColor(0, 0, 0));
      return (
        result,
        RgbColor(
          _memory.readU8(outPtr + _layout.colorRgbR),
          _memory.readU8(outPtr + _layout.colorRgbG),
          _memory.readU8(outPtr + _layout.colorRgbB),
        ),
      );
    } finally {
      frame.release();
    }
  }

  CResult<CellContentTag> cellGetContentTag(int cell) {
    final raw = _cellGetI32(cell, .contentTag);
    return (raw.$1, CellContentTag.fromValue(raw.$2));
  }

  CResult<bool> cellGetHasHyperlink(int cell) =>
      _cellGetBool(cell, .hasHyperlink);

  CResult<bool> cellGetHasStyling(int cell) => _cellGetBool(cell, .hasStyling);

  CResult<bool> cellGetHasText(int cell) => _cellGetBool(cell, .hasText);

  CResult<bool> cellGetProtected(int cell) => _cellGetBool(cell, .protected);

  CResult<CellSemanticContent> cellGetSemanticContent(int cell) {
    final raw = _cellGetI32(cell, .semanticContent);
    return (raw.$1, CellSemanticContent.fromValue(raw.$2));
  }

  CResult<int> cellGetStyleId(int cell) => _cellGetU16(cell, .styleId);

  CResult<RawCellSummary> cellGetSummary(int cell) {
    final result = Result.fromValue(
      _callCellGetMulti(
        cell,
        _cellSummaryKeys.length,
        _cellMultiKeys,
        _cellMultiValues,
        _multiWritten,
      ),
    );
    if (result != .success) return (result, _emptyCellSummary);
    return (
      result,
      (
        codepoint: _memory.readU32(_cellMultiOut),
        styleId: _memory.readU16(_cellMultiOut + _wasmOutputSlotSize),
        wide: .fromValue(
          _memory.readI32(_cellMultiOut + 2 * _wasmOutputSlotSize),
        ),
      ),
    );
  }

  CResult<CellWide> cellGetWide(int cell) {
    final raw = _cellGetI32(cell, .wide);
    return (raw.$1, CellWide.fromValue(raw.$2));
  }

  CResult<int> gridRefCell(RawGridRef ref) {
    final frame = _scratch.acquire(const []);
    try {
      final refPtr = frame.variableAddress(0, _layout.gridRefSize);
      final outPtr = frame.variableAddress(1, 8, alignment: 8);
      _writeGridRef(refPtr, ref);
      final result = _exports.ghostty_grid_ref_cell(refPtr, outPtr);
      if (result != 0) return (.fromValue(result), 0);
      return (.fromValue(result), _memory.readU64(outPtr));
    } finally {
      frame.release();
    }
  }

  CResult<List<int>> gridRefGraphemes(RawGridRef ref) {
    const bufCount = 32;
    const bufSize = bufCount * 4;
    final frame = _scratch.acquire(const []);
    try {
      final refPtr = frame.variableAddress(0, _layout.gridRefSize);
      final outLen = frame.variableAddress(
        1,
        wasm32PointerSize,
        alignment: wasm32PointerSize,
      );
      var buf = frame.variable(2, bufSize, alignment: 4);
      _writeGridRef(refPtr, ref);
      var result = Result.fromValue(
        _exports.ghostty_grid_ref_graphemes(
          refPtr,
          buf.address,
          bufCount,
          outLen,
        ),
      );
      var len = result == .success || result == .outOfSpace
          ? _memory.readU32(outLen)
          : 0;

      if (result == .outOfSpace) {
        final bigSize = len * 4;
        buf = frame.variable(2, bigSize, alignment: 4);
        result = Result.fromValue(
          _exports.ghostty_grid_ref_graphemes(refPtr, buf.address, len, outLen),
        );
        if (result == .success || result == .outOfSpace) {
          len = _memory.readU32(outLen);
        }
        if (result != .success) return (result, const []);
        return (
          result,
          [for (var i = 0; i < len; i++) _memory.readU32(buf.address + i * 4)],
        );
      }
      if (result != .success) return (result, const []);
      return (
        result,
        [for (var i = 0; i < len; i++) _memory.readU32(buf.address + i * 4)],
      );
    } finally {
      frame.release();
    }
  }

  CResult<String> gridRefHyperlinkUri(RawGridRef ref) {
    const initSize = 256;
    final frame = _scratch.acquire(const []);
    try {
      final refPtr = frame.variableAddress(0, _layout.gridRefSize);
      final outLen = frame.variableAddress(
        1,
        wasm32PointerSize,
        alignment: wasm32PointerSize,
      );
      var buf = frame.variable(2, initSize);
      _writeGridRef(refPtr, ref);
      var result = Result.fromValue(
        _exports.ghostty_grid_ref_hyperlink_uri(
          refPtr,
          buf.address,
          initSize,
          outLen,
        ),
      );
      var len = result == .success || result == .outOfSpace
          ? _memory.readU32(outLen)
          : 0;

      if (result == .outOfSpace) {
        buf = frame.variable(2, len);
        result = Result.fromValue(
          _exports.ghostty_grid_ref_hyperlink_uri(
            refPtr,
            buf.address,
            len,
            outLen,
          ),
        );
        if (result == .success || result == .outOfSpace) {
          len = _memory.readU32(outLen);
        }
        if (result != .success) return (result, '');
        return (
          result,
          len == 0 ? '' : utf8.decode(_memory.readBytes(buf.address, len)),
        );
      }
      if (result != .success) return (result, '');
      return (
        result,
        len == 0 ? '' : utf8.decode(_memory.readBytes(buf.address, len)),
      );
    } finally {
      frame.release();
    }
  }

  CResult<int> gridRefRow(RawGridRef ref) {
    final frame = _scratch.acquire(const []);
    try {
      final refPtr = frame.variableAddress(0, _layout.gridRefSize);
      final outPtr = frame.variableAddress(1, 8, alignment: 8);
      _writeGridRef(refPtr, ref);
      final result = _exports.ghostty_grid_ref_row(refPtr, outPtr);
      if (result != 0) return (.fromValue(result), 0);
      return (.fromValue(result), _memory.readU64(outPtr));
    } finally {
      frame.release();
    }
  }

  CResult<Style> gridRefStyle(RawGridRef ref) {
    final frame = _scratch.acquire(const []);
    try {
      final refPtr = frame.variableAddress(0, _layout.gridRefSize);
      final stylePtr = frame.variableAddress(1, _layout.styleSize);
      _writeGridRef(refPtr, ref);
      _memory.writeU32(stylePtr, _layout.styleSize);
      final result = _exports.ghostty_grid_ref_style(refPtr, stylePtr);
      if (result != 0) return (.fromValue(result), const Style());
      return (.fromValue(result), _readStyle(stylePtr));
    } finally {
      frame.release();
    }
  }

  Result renderStateBeginUpdate(int state, int terminal) {
    return .fromValue(
      _exports.ghostty_render_state_begin_update(state, terminal),
    );
  }

  Result renderStateClean(int state) {
    return .fromValue(_exports.ghostty_render_state_clean(state));
  }

  Result renderStateEndUpdate(int state) {
    return .fromValue(_exports.ghostty_render_state_end_update(state));
  }

  void renderStateFree(int handle) {
    _exports.ghostty_render_state_free(handle);
  }

  CResult<TerminalColors> renderStateGetColors(int state) {
    final frame = _scratch.acquire(const []);
    try {
      final colorsPtr = frame.variableAddress(
        0,
        _layout.colorsSize,
        alignment: _layout.maxAlignment,
      );
      _memory.writeU32(colorsPtr, _layout.colorsSize);
      final result = Result.fromValue(
        _exports.ghostty_render_state_get(
          state,
          RenderStateData.colors.value,
          colorsPtr,
        ),
      );
      if (result != .success) return (result, _emptyTerminalColors);

      RgbColor rgbAt(int offset) => RgbColor(
        _memory.readU8(colorsPtr + offset),
        _memory.readU8(colorsPtr + offset + 1),
        _memory.readU8(colorsPtr + offset + 2),
      );

      final bg = rgbAt(_layout.colorsBg);
      final fg = rgbAt(_layout.colorsFg);
      final cursorHasValue =
          _memory.readU8(colorsPtr + _layout.colorsCursorHasValue) != 0;
      final cursor = cursorHasValue ? rgbAt(_layout.colorsCursor) : null;

      final palette = <RgbColor>[
        for (var i = 0; i < 256; i++)
          rgbAt(_layout.colorsPalette + i * _layout.colorRgbSize),
      ];

      return (
        result,
        TerminalColors(
          foreground: fg,
          background: bg,
          cursor: cursor,
          palette: palette,
        ),
      );
    } finally {
      frame.release();
    }
  }

  CResult<int> renderStateGetCols(int state) {
    return _renderStateGetU16(state, .cols);
  }

  CResult<RenderStateCursor> renderStateGetCursor(int state) {
    final frame = _scratch.acquire(const []);
    try {
      final cursorPtr = frame.variableAddress(
        0,
        _layout.cursorSize,
        alignment: _layout.maxAlignment,
      );
      _memory.writeU32(cursorPtr, _layout.cursorSize);
      final result = Result.fromValue(
        _exports.ghostty_render_state_get(
          state,
          RenderStateData.cursor.value,
          cursorPtr,
        ),
      );
      if (result != .success) return (result, _emptyRenderStateCursor);

      final inViewport =
          _memory.readU8(cursorPtr + _layout.cursorViewportHasValue) != 0;
      final visible = _memory.readU8(cursorPtr + _layout.cursorVisible) != 0;
      final blinking = _memory.readU8(cursorPtr + _layout.cursorBlinking) != 0;
      final passwordInput =
          _memory.readU8(cursorPtr + _layout.cursorPasswordInput) != 0;
      final visualStyle = RenderStateCursorVisualStyle.fromValue(
        _memory.readI32(cursorPtr + _layout.cursorVisualStyle),
      );
      return (
        result,
        RenderStateCursor(
          viewportHasValue: inViewport,
          viewportX: inViewport
              ? _memory.readU16(cursorPtr + _layout.cursorViewportX)
              : 0,
          viewportY: inViewport
              ? _memory.readU16(cursorPtr + _layout.cursorViewportY)
              : 0,
          wideTail:
              inViewport &&
              _memory.readU8(cursorPtr + _layout.cursorWideTail) != 0,
          visible: visible,
          blinking: blinking,
          passwordInput: passwordInput,
          visualStyle: visualStyle,
        ),
      );
    } finally {
      frame.release();
    }
  }

  CResult<RenderStateDirty> renderStateGetDirty(int state) {
    final raw = _renderStateGetI32(state, .dirty);
    return (raw.$1, RenderStateDirty.fromValue(raw.$2));
  }

  CResult<int> renderStateGetRows(int state) {
    return _renderStateGetU16(state, .rows);
  }

  RawRenderStateSummary renderStateGetSummary(int state) {
    final result = Result.fromValue(
      _exports.ghostty_render_state_get_multi(
        state,
        _renderStateSummaryKeys.length,
        _renderStateSummaryMultiKeys,
        _renderStateSummaryMultiValues,
        _multiWritten,
      ),
    );
    checkRequiredCode(
      result.value,
      operation: 'ghostty_render_state_get_multi',
    );
    return (
      cols: _memory.readU16(_renderStateSummaryMultiOut),
      rows: _memory.readU16(_renderStateSummaryMultiOut + _wasmOutputSlotSize),
      dirty: .fromValue(
        _memory.readI32(_renderStateSummaryMultiOut + 2 * _wasmOutputSlotSize),
      ),
    );
  }

  CResult<int> renderStateNew() {
    final frame = _scratch.acquire(const []);
    try {
      final outPtr = frame.variableAddress(
        0,
        wasm32PointerSize,
        alignment: wasm32PointerSize,
      );
      final result = _exports.ghostty_render_state_new(0, outPtr);
      if (result != Result.success.value) return (.fromValue(result), 0);
      return (.fromValue(result), _exports.ghostty_wasm_take_opaque(outPtr));
    } finally {
      frame.release();
    }
  }

  Result renderStateSetDirty(int state, RenderStateDirty dirty) {
    final frame = _scratch.acquire(const []);
    try {
      final valPtr = frame.variableAddress(
        0,
        wasm32PointerSize,
        alignment: wasm32PointerSize,
      );
      _memory.writeI32(valPtr, dirty.value);
      final result = _exports.ghostty_render_state_set(
        state,
        RenderStateOption.dirty.value,
        valPtr,
      );
      return Result.fromValue(result);
    } finally {
      frame.release();
    }
  }

  Result renderStateUpdate(int state, int terminal) {
    return .fromValue(_exports.ghostty_render_state_update(state, terminal));
  }

  void rowCellsFree(int handle) {
    _exports.ghostty_render_state_row_cells_free(handle);
  }

  CResult<RgbColor> rowCellsGetBgColor(int cells) {
    final frame = _scratch.acquire(const []);
    try {
      final outPtr = frame.variableAddress(0, _layout.colorRgbSize);
      final result = Result.fromValue(
        _exports.ghostty_render_state_row_cells_get(
          cells,
          RenderStateRowCellsData.bgColor.value,
          outPtr,
        ),
      );
      if (result != .success) return (result, const RgbColor(0, 0, 0));
      return (
        result,
        RgbColor(
          _memory.readU8(outPtr + _layout.colorRgbR),
          _memory.readU8(outPtr + _layout.colorRgbG),
          _memory.readU8(outPtr + _layout.colorRgbB),
        ),
      );
    } finally {
      frame.release();
    }
  }

  CResult<int> rowCellsGetBgColorArgb(int cells) {
    final frame = _scratch.acquire(const []);
    try {
      final outPtr = frame.variableAddress(0, _layout.colorRgbSize);
      final result = Result.fromValue(
        _exports.ghostty_render_state_row_cells_get(
          cells,
          RenderStateRowCellsData.bgColor.value,
          outPtr,
        ),
      );
      if (result != .success) return (result, 0);
      return (
        result,
        0xFF000000 |
            (_memory.readU8(outPtr + _layout.colorRgbR) << 16) |
            (_memory.readU8(outPtr + _layout.colorRgbG) << 8) |
            _memory.readU8(outPtr + _layout.colorRgbB),
      );
    } finally {
      frame.release();
    }
  }

  CResult<RgbColor> rowCellsGetFgColor(int cells) {
    final frame = _scratch.acquire(const []);
    try {
      final outPtr = frame.variableAddress(0, _layout.colorRgbSize);
      final result = Result.fromValue(
        _exports.ghostty_render_state_row_cells_get(
          cells,
          RenderStateRowCellsData.fgColor.value,
          outPtr,
        ),
      );
      if (result != .success) return (result, const RgbColor(0, 0, 0));
      return (
        result,
        RgbColor(
          _memory.readU8(outPtr + _layout.colorRgbR),
          _memory.readU8(outPtr + _layout.colorRgbG),
          _memory.readU8(outPtr + _layout.colorRgbB),
        ),
      );
    } finally {
      frame.release();
    }
  }

  CResult<int> rowCellsGetFgColorArgb(int cells) {
    final frame = _scratch.acquire(const []);
    try {
      final outPtr = frame.variableAddress(0, _layout.colorRgbSize);
      final result = Result.fromValue(
        _exports.ghostty_render_state_row_cells_get(
          cells,
          RenderStateRowCellsData.fgColor.value,
          outPtr,
        ),
      );
      if (result != .success) return (result, 0);
      return (
        result,
        0xFF000000 |
            (_memory.readU8(outPtr + _layout.colorRgbR) << 16) |
            (_memory.readU8(outPtr + _layout.colorRgbG) << 8) |
            _memory.readU8(outPtr + _layout.colorRgbB),
      );
    } finally {
      frame.release();
    }
  }

  CResult<int> rowCellsGetGraphemeLen(int cells) {
    final frame = _scratch.acquire(const []);
    try {
      final outPtr = frame.variableAddress(
        0,
        wasm32PointerSize,
        alignment: wasm32PointerSize,
      );
      final result = Result.fromValue(
        _exports.ghostty_render_state_row_cells_get(
          cells,
          RenderStateRowCellsData.graphemesLen.value,
          outPtr,
        ),
      );
      if (result != .success) return (result, 0);
      return (result, _memory.readU32(outPtr));
    } finally {
      frame.release();
    }
  }

  CResult<List<int>> rowCellsGetGraphemes(int cells, int len) {
    if (len <= 0) return (Result.success, const []);
    final bufSize = len * 4;
    final frame = _scratch.acquire(const []);
    try {
      final buf = frame.variableAddress(0, bufSize, alignment: 4);
      final result = Result.fromValue(
        _exports.ghostty_render_state_row_cells_get(
          cells,
          RenderStateRowCellsData.graphemesBuf.value,
          buf,
        ),
      );
      if (result != .success) return (result, const []);
      return (
        result,
        [for (var i = 0; i < len; i++) _memory.readU32(buf + i * 4)],
      );
    } finally {
      frame.release();
    }
  }

  CResult<String> rowCellsGetGraphemesUtf8(int cells) {
    const inlineCap = 64;
    final frame = _scratch.acquire(const []);
    try {
      final bufferPtr = frame.variableAddress(0, _layout.bufferSize);
      var data = frame.variable(1, inlineCap);

      void writeBuffer() {
        _memory.writeU32(bufferPtr + _layout.bufferPtr, data.address);
        _memory.writeU32(bufferPtr + _layout.bufferCap, data.capacity);
        _memory.writeU32(bufferPtr + _layout.bufferLen, 0);
      }

      writeBuffer();
      var result = Result.fromValue(
        _exports.ghostty_render_state_row_cells_get(
          cells,
          RenderStateRowCellsData.graphemesUtf8.value,
          bufferPtr,
        ),
      );
      var len = result == .success || result == .outOfSpace
          ? _memory.readU32(bufferPtr + _layout.bufferLen)
          : 0;

      if (result == .outOfSpace) {
        data = frame.variable(1, len);
        writeBuffer();
        result = Result.fromValue(
          _exports.ghostty_render_state_row_cells_get(
            cells,
            RenderStateRowCellsData.graphemesUtf8.value,
            bufferPtr,
          ),
        );
        if (result == .success || result == .outOfSpace) {
          len = _memory.readU32(bufferPtr + _layout.bufferLen);
        }
      }

      final value = result == .success && len > 0
          ? utf8.decode(_memory.readBytes(data.address, len))
          : '';
      return (result, value);
    } finally {
      frame.release();
    }
  }

  CResult<bool> rowCellsGetHasStyling(int cells) {
    final frame = _scratch.acquire(const []);
    try {
      final outPtr = frame.variableAddress(0, 1);
      final result = Result.fromValue(
        _exports.ghostty_render_state_row_cells_get(
          cells,
          RenderStateRowCellsData.hasStyling.value,
          outPtr,
        ),
      );
      if (result != .success) return (result, false);
      return (result, _memory.readU8(outPtr) != 0);
    } finally {
      frame.release();
    }
  }

  CResult<int> rowCellsGetRawCell(int cells) {
    final frame = _scratch.acquire(const []);
    try {
      final outPtr = frame.variableAddress(0, 8, alignment: 8);
      final result = Result.fromValue(
        _exports.ghostty_render_state_row_cells_get(
          cells,
          RenderStateRowCellsData.raw.value,
          outPtr,
        ),
      );
      if (result != .success) return (result, 0);
      return (result, _memory.readU64(outPtr));
    } finally {
      frame.release();
    }
  }

  CResult<bool> rowCellsGetSelected(int cells) {
    final frame = _scratch.acquire(const []);
    try {
      final outPtr = frame.variableAddress(0, 1);
      final result = Result.fromValue(
        _exports.ghostty_render_state_row_cells_get(
          cells,
          RenderStateRowCellsData.selected.value,
          outPtr,
        ),
      );
      if (result != .success) return (result, false);
      return (result, _memory.readU8(outPtr) != 0);
    } finally {
      frame.release();
    }
  }

  CResult<Style> rowCellsGetStyle(int cells) {
    final size = _layout.styleSize;
    final frame = _scratch.acquire(const []);
    try {
      final stylePtr = frame.variableAddress(0, size);
      _memory.writeU32(stylePtr, size);
      final result = Result.fromValue(
        _exports.ghostty_render_state_row_cells_get(
          cells,
          RenderStateRowCellsData.style.value,
          stylePtr,
        ),
      );
      if (result != .success) return (result, const Style());
      return (result, _readStyle(stylePtr));
    } finally {
      frame.release();
    }
  }

  CResult<RawRowCellsSummary> rowCellsGetSummary(int cells) {
    final result = Result.fromValue(
      _exports.ghostty_render_state_row_cells_get_multi(
        cells,
        _rowCellsSummaryKeys.length,
        _rowCellsMultiKeys,
        _rowCellsMultiValues,
        _multiWritten,
      ),
    );
    if (result != .success) return (result, _emptyRowCellsSummary);
    return (
      result,
      (
        rawCell: _memory.readU64(_rowCellsMultiOut),
        graphemeLen: _memory.readU32(_rowCellsMultiOut + _wasmOutputSlotSize),
        selected:
            _memory.readU8(_rowCellsMultiOut + 2 * _wasmOutputSlotSize) != 0,
      ),
    );
  }

  Result rowCellsInit(int cells, int iterator) {
    final frame = _scratch.acquire(const []);
    try {
      final ptrPtr = frame.variableAddress(
        0,
        wasm32PointerSize,
        alignment: wasm32PointerSize,
      );
      _memory.writeU32(ptrPtr, cells);
      final result = _exports.ghostty_render_state_row_get(
        iterator,
        RenderStateRowData.cells.value,
        ptrPtr,
      );
      return Result.fromValue(result);
    } finally {
      frame.release();
    }
  }

  CResult<int> rowCellsNew() {
    final frame = _scratch.acquire(const []);
    try {
      final outPtr = frame.variableAddress(
        0,
        wasm32PointerSize,
        alignment: wasm32PointerSize,
      );
      final result = Result.fromValue(
        _exports.ghostty_render_state_row_cells_new(0, outPtr),
      );
      if (result != .success) return (result, 0);
      return (result, _exports.ghostty_wasm_take_opaque(outPtr));
    } finally {
      frame.release();
    }
  }

  bool rowCellsNext(int cells) =>
      _exports.ghostty_render_state_row_cells_next(cells) != 0;

  Result rowCellsSelect(int cells, int x) {
    return Result.fromValue(
      _exports.ghostty_render_state_row_cells_select(cells, x),
    );
  }

  CResult<bool> rowGetDirty(int row) => _rowGetBool(row, .dirty);

  CResult<bool> rowGetGrapheme(int row) => _rowGetBool(row, .grapheme);

  CResult<bool> rowGetHyperlink(int row) => _rowGetBool(row, .hyperlink);

  CResult<bool> rowGetKittyVirtualPlaceholder(int row) {
    return _rowGetBool(row, .kittyVirtualPlaceholder);
  }

  CResult<RowSemanticPrompt> rowGetSemanticPrompt(int row) {
    final frame = _scratch.acquire(const []);
    try {
      final outPtr = frame.variableAddress(
        0,
        wasm32PointerSize,
        alignment: wasm32PointerSize,
      );
      final result = _callRowGet(row, .semanticPrompt, outPtr);
      if (result != Result.success.value) return (.fromValue(result), .none);
      return (.fromValue(result), .fromValue(_memory.readI32(outPtr)));
    } finally {
      frame.release();
    }
  }

  CResult<bool> rowGetStyled(int row) => _rowGetBool(row, .styled);

  CResult<RawRowSummary> rowGetSummary(int row) {
    const keys = _rowSummaryKeys;
    for (var i = 0; i < keys.length; i++) {
      _memory.writeU32(_multiKeys + i * _wasmEnumSize, keys[i].value);
      _memory.writeU32(
        _multiValues + i * _wasmPointerSize,
        _multiOut + i * _wasmOutputSlotSize,
      );
    }
    final result = Result.fromValue(
      _callRowGetMulti(
        row,
        keys.length,
        _multiKeys,
        _multiValues,
        _multiWritten,
      ),
    );
    if (result != .success) return (result, _emptyRowSummary);
    return (
      result,
      (
        wrap: _memory.readU8(_multiOut) != 0,
        wrapContinuation: _memory.readU8(_multiOut + _wasmOutputSlotSize) != 0,
        grapheme: _memory.readU8(_multiOut + 2 * _wasmOutputSlotSize) != 0,
        styled: _memory.readU8(_multiOut + 3 * _wasmOutputSlotSize) != 0,
        hyperlink: _memory.readU8(_multiOut + 4 * _wasmOutputSlotSize) != 0,
        semanticPrompt: .fromValue(
          _memory.readI32(_multiOut + 5 * _wasmOutputSlotSize),
        ),
        kittyVirtualPlaceholder:
            _memory.readU8(_multiOut + 6 * _wasmOutputSlotSize) != 0,
      ),
    );
  }

  CResult<bool> rowGetWrap(int row) => _rowGetBool(row, .wrap);

  CResult<bool> rowGetWrapContinuation(int row) =>
      _rowGetBool(row, .wrapContinuation);

  void rowIteratorFree(int handle) {
    _exports.ghostty_render_state_row_iterator_free(handle);
  }

  CResult<bool> rowIteratorGetDirty(int iterator) {
    final frame = _scratch.acquire(const []);
    try {
      final outPtr = frame.variableAddress(0, 1);
      final result = Result.fromValue(
        _exports.ghostty_render_state_row_get(
          iterator,
          RenderStateRowData.dirty.value,
          outPtr,
        ),
      );
      if (result != .success) return (result, false);
      return (result, _memory.readU8(outPtr) != 0);
    } finally {
      frame.release();
    }
  }

  CResult<int> rowIteratorGetRawRow(int iterator) {
    final frame = _scratch.acquire(const []);
    try {
      final outPtr = frame.variableAddress(0, 8, alignment: 8);
      final result = Result.fromValue(
        _exports.ghostty_render_state_row_get(
          iterator,
          RenderStateRowData.raw.value,
          outPtr,
        ),
      );
      if (result != .success) return (result, 0);
      return (result, _memory.readU64(outPtr));
    } finally {
      frame.release();
    }
  }

  CResult<({int startCol, int endCol})> rowIteratorGetSelection(int iterator) {
    final size = _layout.renderRowSelectionSize;
    final frame = _scratch.acquire(const []);
    try {
      final outPtr = frame.variableAddress(0, size);
      _zero(outPtr, size);
      _memory.writeU32(outPtr, size);
      final result = Result.fromValue(
        _exports.ghostty_render_state_row_get(
          iterator,
          RenderStateRowData.selection.value,
          outPtr,
        ),
      );
      if (result != .success) return (result, (startCol: 0, endCol: 0));
      return (
        result,
        (
          startCol: _memory.readU16(outPtr + _layout.renderRowSelectionStartX),
          endCol: _memory.readU16(outPtr + _layout.renderRowSelectionEndX),
        ),
      );
    } finally {
      frame.release();
    }
  }

  CResult<RawRowIteratorSummary> rowIteratorGetSummary(int iterator) {
    const keys = _rowIteratorSummaryKeys;
    for (var i = 0; i < keys.length; i++) {
      _memory.writeU32(_multiKeys + i * _wasmEnumSize, keys[i].value);
      _memory.writeU32(
        _multiValues + i * _wasmPointerSize,
        _multiOut + i * _wasmOutputSlotSize,
      );
    }
    final result = Result.fromValue(
      _exports.ghostty_render_state_row_get_multi(
        iterator,
        keys.length,
        _multiKeys,
        _multiValues,
        _multiWritten,
      ),
    );
    if (result != .success) return (result, _emptyRowIteratorSummary);
    return (
      result,
      (
        dirty: _memory.readU8(_multiOut) != 0,
        rawRow: _memory.readU64(_multiOut + _wasmOutputSlotSize),
      ),
    );
  }

  bool rowIteratorGetRawCells(int iterator, RawCellsView view) {
    final frame = _scratch.acquire(const []);
    try {
      final viewPtr = frame.variableAddress(
        0,
        _layout.cellsViewSize,
        alignment: _layout.maxAlignment,
      );
      final result = Result.fromValue(
        _exports.ghostty_render_state_row_get(
          iterator,
          RenderStateRowData.cellsRaw.value,
          viewPtr,
        ),
      );
      if (result != .success) {
        view.clear();
        return false;
      }
      final address = _memory.readPtr(viewPtr + _layout.cellsViewPtr);
      final length = _memory.readU32(viewPtr + _layout.cellsViewLen);
      if (address == 0 && length != 0) {
        throw StateError('GhosttyCellsView has a null pointer with cells.');
      }
      final selection = rowIteratorGetSelection(iterator);
      final hasSelection = checkOptionalCode(
        selection.$1.value,
        operation: 'ghostty_render_state_row_get',
      );
      view.set(
        address: address,
        length: length,
        selection: hasSelection ? selection.$2 : null,
      );
      return true;
    } finally {
      frame.release();
    }
  }

  bool decodeRawCell(RawCellsView view, int index, RawCellData output) {
    if (index < 0 || index >= view.length) return false;
    final raw = _memory.readU64(view.address + index * _layout.cellLayout.size);
    _layout.cellLayout.decodeInto(raw, output);
    return true;
  }

  Result rowIteratorInit(int iterator, int renderState) {
    final frame = _scratch.acquire(const []);
    try {
      final ptrPtr = frame.variableAddress(
        0,
        wasm32PointerSize,
        alignment: wasm32PointerSize,
      );
      _memory.writeU32(ptrPtr, iterator);
      final result = _exports.ghostty_render_state_get(
        renderState,
        RenderStateData.rowIterator.value,
        ptrPtr,
      );
      return Result.fromValue(result);
    } finally {
      frame.release();
    }
  }

  CResult<int> rowIteratorNew() {
    final frame = _scratch.acquire(const []);
    try {
      final outPtr = frame.variableAddress(
        0,
        wasm32PointerSize,
        alignment: wasm32PointerSize,
      );
      final result = Result.fromValue(
        _exports.ghostty_render_state_row_iterator_new(0, outPtr),
      );
      if (result != .success) return (result, 0);
      return (result, _exports.ghostty_wasm_take_opaque(outPtr));
    } finally {
      frame.release();
    }
  }

  bool rowIteratorNext(int iterator) {
    return _exports.ghostty_render_state_row_iterator_next(iterator) != 0;
  }

  int? rowIteratorNextDirty(int iterator) {
    final frame = _scratch.acquire(const []);
    try {
      final outY = frame.variableAddress(0, 2, alignment: 2);
      final hasNext = _exports.ghostty_render_state_row_iterator_next_dirty(
        iterator,
        outY,
      );
      return hasNext == 0 ? null : _memory.readU16(outY);
    } finally {
      frame.release();
    }
  }

  Result rowIteratorSetDirty(int iterator, {required bool dirty}) {
    final frame = _scratch.acquire(const []);
    try {
      final valPtr = frame.variableAddress(0, 1);
      _memory.writeU8(valPtr, dirty ? 1 : 0);
      final result = _exports.ghostty_render_state_row_set(
        iterator,
        RenderStateRowOption.dirty.value,
        valPtr,
      );
      return Result.fromValue(result);
    } finally {
      frame.release();
    }
  }

  CResult<RawGridRef> terminalGridRef(
    int terminal,
    PointTag pointTag,
    Position position,
  ) {
    final frame = _scratch.acquire(const []);
    try {
      final pointPtr = frame.variableAddress(0, _layout.pointSize);
      final gridRefPtr = frame.variableAddress(1, _layout.gridRefSize);
      _writePoint(pointPtr, pointTag, position);
      _memory.writeU32(gridRefPtr, _layout.gridRefSize);
      final result = _exports.ghostty_terminal_grid_ref(
        terminal,
        pointPtr,
        gridRefPtr,
      );
      if (result != 0) return (.fromValue(result), (node: 0, x: 0, y: 0));
      return (.fromValue(result), _readGridRef(gridRefPtr));
    } finally {
      frame.release();
    }
  }

  CResult<int> terminalGridRefTrack(
    int terminal,
    PointTag pointTag,
    Position position,
  ) {
    final frame = _scratch.acquire(const []);
    try {
      final pointPtr = frame.variableAddress(0, _layout.pointSize);
      final outPtr = frame.variableAddress(
        1,
        wasm32PointerSize,
        alignment: wasm32PointerSize,
      );
      _writePoint(pointPtr, pointTag, position);
      final result = _exports.ghostty_terminal_grid_ref_track(
        terminal,
        pointPtr,
        outPtr,
      );
      if (result != Result.success.value) return (.fromValue(result), 0);
      return (.fromValue(result), _exports.ghostty_wasm_take_opaque(outPtr));
    } finally {
      frame.release();
    }
  }

  CResult<Position> terminalPointFromGridRef(
    int terminal,
    RawGridRef ref,
    PointTag pointTag,
  ) {
    final size = _layout.pointCoordinateSize;
    final frame = _scratch.acquire(const []);
    try {
      final refPtr = frame.variableAddress(0, _layout.gridRefSize);
      final outPtr = frame.variableAddress(1, size);
      _writeGridRef(refPtr, ref);
      final result = Result.fromValue(
        _exports.ghostty_terminal_point_from_grid_ref(
          terminal,
          refPtr,
          pointTag.value,
          outPtr,
        ),
      );
      if (result != .success) return (result, const Position(row: 0, col: 0));
      final col = _memory.readU16(outPtr + _layout.pointCoordinateX);
      final row = _memory.readU32(outPtr + _layout.pointCoordinateY);
      return (result, Position(row: row, col: col));
    } finally {
      frame.release();
    }
  }

  void trackedGridRefFree(int ref) {
    _exports.ghostty_tracked_grid_ref_free(ref);
  }

  bool trackedGridRefHasValue(int ref) {
    return _exports.ghostty_tracked_grid_ref_has_value(ref) != 0;
  }

  CResult<Position> trackedGridRefPoint(int ref, PointTag pointTag) {
    final size = _layout.pointCoordinateSize;
    final frame = _scratch.acquire(const []);
    try {
      final outPtr = frame.variableAddress(0, size);
      final result = Result.fromValue(
        _exports.ghostty_tracked_grid_ref_point(ref, pointTag.value, outPtr),
      );
      if (result != .success) return (result, const Position(row: 0, col: 0));
      final col = _memory.readU16(outPtr + _layout.pointCoordinateX);
      final row = _memory.readU32(outPtr + _layout.pointCoordinateY);
      return (result, Position(row: row, col: col));
    } finally {
      frame.release();
    }
  }

  Result trackedGridRefSet(
    int ref,
    int terminal,
    PointTag pointTag,
    Position position,
  ) {
    final frame = _scratch.acquire(const []);
    try {
      final pointPtr = frame.variableAddress(0, _layout.pointSize);
      _writePoint(pointPtr, pointTag, position);
      final result = _exports.ghostty_tracked_grid_ref_set(
        ref,
        terminal,
        pointPtr,
      );
      return .fromValue(result);
    } finally {
      frame.release();
    }
  }

  CResult<RawGridRef> trackedGridRefSnapshot(int ref) {
    final frame = _scratch.acquire(const []);
    try {
      final gridRefPtr = frame.variableAddress(0, _layout.gridRefSize);
      _memory.writeU32(gridRefPtr, _layout.gridRefSize);
      final result = Result.fromValue(
        _exports.ghostty_tracked_grid_ref_snapshot(ref, gridRefPtr),
      );
      if (result != .success) return (result, (node: 0, x: 0, y: 0));
      return (result, _readGridRef(gridRefPtr));
    } finally {
      frame.release();
    }
  }

  int _allocateBytes(int size) {
    final pointer = _exports.allocateBytes(size);
    if (pointer == 0) throw const OutOfMemoryException();
    return pointer;
  }

  int _allocateSize() {
    final pointer = _exports.allocateBytes(4);
    if (pointer == 0) throw const OutOfMemoryException();
    if (pointer % _wasmSizeSize != 0) {
      _exports.freeBytes(pointer, 4);
      throw StateError('libghostty WASM allocator returned misaligned memory.');
    }
    return pointer;
  }

  int _callCellGet(int cell, CellData data, int outPtr) {
    final fn = (_exports as JSObject)['ghostty_cell_get']! as JSFunction;
    return (fn.callAsFunction(
              null,
              _toBigInt(cell),
              data.value.toJS,
              outPtr.toJS,
            )!
            as JSNumber)
        .toDartInt;
  }

  int _callCellGetMulti(
    int cell,
    int count,
    int keys,
    int values,
    int outWritten,
  ) {
    // WebAssembly exposes i64 parameters as JavaScript BigInt values, while
    // Dart's typed callAsFunction overload accepts only four arguments. These
    // C functions take five, so callMethodVarArgs is the supported bridge. The
    // argument lists are reused because this path runs for every cell and row.
    // https://api.dart.dev/dart-js_interop_unsafe/JSObjectUnsafeUtilExtension/callMethodVarArgs.html
    final arguments = _cellGetMultiArguments;
    arguments[0] = _toBigInt(cell);
    arguments[1] = count.toJS;
    arguments[2] = keys.toJS;
    arguments[3] = values.toJS;
    arguments[4] = outWritten.toJS;
    return (_exports as JSObject)
        .callMethodVarArgs<JSNumber>(_cellGetMultiMethod, arguments)
        .toDartInt;
  }

  int _callRowGet(int row, RowData data, int outPtr) {
    final fn = (_exports as JSObject)['ghostty_row_get']! as JSFunction;
    return (fn.callAsFunction(
              null,
              _toBigInt(row),
              data.value.toJS,
              outPtr.toJS,
            )!
            as JSNumber)
        .toDartInt;
  }

  int _callRowGetMulti(
    int row,
    int count,
    int keys,
    int values,
    int outWritten,
  ) {
    final arguments = _rowGetMultiArguments;
    arguments[0] = _toBigInt(row);
    arguments[1] = count.toJS;
    arguments[2] = keys.toJS;
    arguments[3] = values.toJS;
    arguments[4] = outWritten.toJS;
    return (_exports as JSObject)
        .callMethodVarArgs<JSNumber>(_rowGetMultiMethod, arguments)
        .toDartInt;
  }

  CResult<bool> _cellGetBool(int cell, CellData data) {
    final frame = _scratch.acquire(const []);
    try {
      final outPtr = frame.variableAddress(0, 1);
      final result = _callCellGet(cell, data, outPtr);
      if (result != 0) return (.fromValue(result), false);
      return (.fromValue(result), _memory.readU8(outPtr) != 0);
    } finally {
      frame.release();
    }
  }

  CResult<int> _cellGetI32(int cell, CellData data) {
    final frame = _scratch.acquire(const []);
    try {
      final outPtr = frame.variableAddress(
        0,
        wasm32PointerSize,
        alignment: wasm32PointerSize,
      );
      final result = _callCellGet(cell, data, outPtr);
      if (result != 0) return (.fromValue(result), 0);
      return (.fromValue(result), _memory.readI32(outPtr));
    } finally {
      frame.release();
    }
  }

  CResult<int> _cellGetU16(int cell, CellData data) {
    final frame = _scratch.acquire(const []);
    try {
      final outPtr = frame.variableAddress(
        0,
        wasm32PointerSize,
        alignment: wasm32PointerSize,
      );
      final result = _callCellGet(cell, data, outPtr);
      if (result != 0) return (.fromValue(result), 0);
      return (.fromValue(result), _memory.readU16(outPtr));
    } finally {
      frame.release();
    }
  }

  CResult<int> _cellGetU32(int cell, CellData data) {
    final frame = _scratch.acquire(const []);
    try {
      final outPtr = frame.variableAddress(
        0,
        wasm32PointerSize,
        alignment: wasm32PointerSize,
      );
      final result = _callCellGet(cell, data, outPtr);
      if (result != 0) return (.fromValue(result), 0);
      return (.fromValue(result), _memory.readU32(outPtr));
    } finally {
      frame.release();
    }
  }

  RawGridRef _readGridRef(int ptr) {
    return (
      node: _memory.readPtr(ptr + _layout.gridRefNode),
      x: _memory.readU16(ptr + _layout.gridRefX),
      y: _memory.readU16(ptr + _layout.gridRefY),
    );
  }

  RawColor _readRawColor(int addr) {
    return (
      tag: StyleColorTag.fromValue(_memory.readU32(addr)),
      palette: _memory.readU8(addr + _layout.styleColorR),
      r: _memory.readU8(addr + _layout.styleColorR),
      g: _memory.readU8(addr + _layout.styleColorG),
      b: _memory.readU8(addr + _layout.styleColorB),
    );
  }

  Style _readStyle(int stylePtr) {
    final ulRaw = _readRawColor(stylePtr + _layout.styleUnderlineColor);
    return Style(
      foreground: cellColorFromRaw(_readRawColor(stylePtr + _layout.styleFg)),
      background: cellColorFromRaw(_readRawColor(stylePtr + _layout.styleBg)),
      underlineColor: switch (ulRaw.tag) {
        .rgb || .palette => cellColorFromRaw(ulRaw),
        .none => null,
      },
      bold: _memory.readU8(stylePtr + _layout.styleBold) != 0,
      italic: _memory.readU8(stylePtr + _layout.styleItalic) != 0,
      faint: _memory.readU8(stylePtr + _layout.styleFaint) != 0,
      blink: _memory.readU8(stylePtr + _layout.styleBlink) != 0,
      inverse: _memory.readU8(stylePtr + _layout.styleInverse) != 0,
      invisible: _memory.readU8(stylePtr + _layout.styleInvisible) != 0,
      strikethrough: _memory.readU8(stylePtr + _layout.styleStrikethrough) != 0,
      overline: _memory.readU8(stylePtr + _layout.styleOverline) != 0,
      underline: .fromValue(_memory.readI32(stylePtr + _layout.styleUnderline)),
    );
  }

  CResult<int> _renderStateGetI32(int state, RenderStateData data) {
    final frame = _scratch.acquire(const []);
    try {
      final outPtr = frame.variableAddress(
        0,
        wasm32PointerSize,
        alignment: wasm32PointerSize,
      );
      final result = _exports.ghostty_render_state_get(
        state,
        data.value,
        outPtr,
      );
      if (result != 0) return (.fromValue(result), 0);
      return (.fromValue(result), _memory.readI32(outPtr));
    } finally {
      frame.release();
    }
  }

  CResult<int> _renderStateGetU16(int state, RenderStateData data) {
    final frame = _scratch.acquire(const []);
    try {
      final outPtr = frame.variableAddress(
        0,
        wasm32PointerSize,
        alignment: wasm32PointerSize,
      );
      final result = _exports.ghostty_render_state_get(
        state,
        data.value,
        outPtr,
      );
      if (result != 0) return (.fromValue(result), 0);
      return (.fromValue(result), _memory.readU16(outPtr));
    } finally {
      frame.release();
    }
  }

  CResult<bool> _rowGetBool(int row, RowData data) {
    final frame = _scratch.acquire(const []);
    try {
      final outPtr = frame.variableAddress(0, 1);
      final result = _callRowGet(row, data, outPtr);
      if (result != 0) return (.fromValue(result), false);
      return (.fromValue(result), _memory.readU8(outPtr) != 0);
    } finally {
      frame.release();
    }
  }

  void _writeGridRef(int ptr, RawGridRef ref) {
    _memory.writeU32(ptr, _layout.gridRefSize);
    _memory.writeU32(ptr + _layout.gridRefNode, ref.node);
    _memory.writeU16(ptr + _layout.gridRefX, ref.x);
    _memory.writeU16(ptr + _layout.gridRefY, ref.y);
  }

  void _writeMultiKeys<T extends Enum>(
    List<T> keys,
    int keyPtr,
    int valuePtr,
    int outPtr,
  ) {
    for (var i = 0; i < keys.length; i++) {
      final key = switch (keys[i]) {
        final RenderStateData value => value.value,
        final RenderStateRowData value => value.value,
        final RenderStateRowCellsData value => value.value,
        final CellData value => value.value,
        _ => throw StateError('Unsupported render query key.'),
      };
      _memory.writeU32(keyPtr + i * _wasmEnumSize, key);
      _memory.writeU32(
        valuePtr + i * _wasmPointerSize,
        outPtr + i * _wasmOutputSlotSize,
      );
    }
  }

  void _writePoint(int pointPtr, PointTag pointTag, Position position) {
    _memory.writeU32(pointPtr, pointTag.value);
    _memory.writeU16(pointPtr + _layout.pointX, position.col);
    _memory.writeU32(pointPtr + _layout.pointY, position.row);
  }

  void _zero(int ptr, int len) {
    for (var i = 0; i < len; i++) {
      _memory.writeU8(ptr + i, 0);
    }
  }

  static JSAny _toBigInt(int value) {
    return _jsBigInt.callAsFunction(null, value.toJS)!;
  }
}

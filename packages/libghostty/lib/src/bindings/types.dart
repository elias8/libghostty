import '../generated/libghostty_enums.g.dart';
import '../types/color.dart';
import '../types/kitty_graphics.dart';
import 'result_helpers.dart';

const defaultRawColor = (tag: StyleColorTag.none, palette: 0, r: 0, g: 0, b: 0);

CellColor cellColorFromRaw(RawColor raw) => switch (raw.tag) {
  StyleColorTag.palette => PaletteColor(raw.palette),
  StyleColorTag.rgb => RgbColor(raw.r, raw.g, raw.b),
  StyleColorTag.none => const DefaultColor(),
};

/// Unwraps a C result, throwing on a non-success code.
T check<T>(CResult<T> result, {String? operation}) {
  checkCode(result.$1, operation: operation);
  return result.$2;
}

/// Throws when [code] is a non-success result.
@pragma('vm:prefer-inline')
void checkCode(Result code, {String? operation}) =>
    checkResultCode(code.value, operation: operation);

/// A C function result: the result code paired with a value.
typedef CResult<T> = (Result code, T value);

/// Scalar cell metadata captured by one boundary query.
typedef RawCellSummary = ({int codepoint, int styleId, CellWide wide});

/// Decoded fields from one borrowed packed cell value.
///
/// The caller owns and reuses the instance. Read or copy its fields before the
/// next cell is decoded.
final class RawCellData {
  var rawCell = 0;
  CellContentTag contentTag = .codepoint;
  var codepoint = 0;
  var hasGrapheme = false;
  var styleId = 0;
  CellWide wide = .narrow;
  var isProtected = false;
  var hasHyperlink = false;
  CellSemanticContent semanticContent = .output;
  var hasBackgroundRgb = false;
  var backgroundR = 0;
  var backgroundG = 0;
  var backgroundB = 0;

  void set({
    required int rawCell,
    required CellContentTag contentTag,
    required int codepoint,
    required bool hasGrapheme,
    required int styleId,
    required CellWide wide,
    required bool isProtected,
    required bool hasHyperlink,
    required CellSemanticContent semanticContent,
    required bool hasBackgroundRgb,
    required int backgroundR,
    required int backgroundG,
    required int backgroundB,
  }) {
    this.rawCell = rawCell;
    this.contentTag = contentTag;
    this.codepoint = codepoint;
    this.hasGrapheme = hasGrapheme;
    this.styleId = styleId;
    this.wide = wide;
    this.isProtected = isProtected;
    this.hasHyperlink = hasHyperlink;
    this.semanticContent = semanticContent;
    this.hasBackgroundRgb = hasBackgroundRgb;
    this.backgroundR = backgroundR;
    this.backgroundG = backgroundG;
    this.backgroundB = backgroundB;
  }
}

/// C tagged union for a color.
typedef RawColor = ({StyleColorTag tag, int palette, int r, int g, int b});

/// An untracked native grid reference.
typedef RawGridRef = ({int node, int x, int y});

/// Copied Kitty Unicode placement fields returned by the bindings.
typedef RawKittyUnicodePlacement = ({
  RawGridRef topLeft,
  int imageId,
  int placementId,
  int column,
  int row,
  int columns,
  int rows,
  KittyUnicodePlacementRenderInfo? renderInfo,
});

/// Render-state dimensions and dirty state returned by a batched query.
typedef RawRenderStateSummary = ({int cols, int rows, RenderStateDirty dirty});

/// Current render cell data captured by one boundary query.
typedef RawRowCellsSummary = ({int rawCell, int graphemeLen, bool selected});

/// Current render row data captured by one boundary query.
typedef RawRowIteratorSummary = ({bool dirty, int rawRow});

/// Scalar row metadata captured by one boundary query.
typedef RawRowSummary = ({
  bool wrap,
  bool wrapContinuation,
  bool grapheme,
  bool styled,
  bool hyperlink,
  RowSemanticPrompt semanticPrompt,
  bool kittyVirtualPlaceholder,
});

/// A native selection range using untracked grid references.
typedef RawSelection = ({RawGridRef start, RawGridRef end, bool rectangle});

/// Readable selection gesture state captured by one boundary query.
typedef RawSelectionGestureState = ({
  int clickCount,
  bool dragged,
  SelectionGestureAutoscroll autoscroll,
  SelectionGestureBehavior behavior,
  RawGridRef? anchor,
});

/// Borrowed contiguous cell storage from a render-state row.
///
/// This type is internal to the bindings. A view is reused by its owner rather
/// than allocated for every row. The address is valid only until the render
/// state is updated.
final class RawCellsView {
  var address = 0;
  var length = 0;

  /// Row-local selection bounds captured while the view is acquired.
  int? selectionStart;
  int? selectionEnd;

  void clear() {
    address = 0;
    length = 0;
    selectionStart = null;
    selectionEnd = null;
  }

  void set({
    required int address,
    required int length,
    ({int startCol, int endCol})? selection,
  }) {
    this.address = address;
    this.length = length;
    selectionStart = selection?.startCol;
    selectionEnd = selection?.endCol;
  }

  bool isSelected(int index) {
    final start = selectionStart;
    final end = selectionEnd;
    return start != null && end != null && index >= start && index <= end;
  }
}

/// An opaque libghostty handle represented by its native address or Wasm
/// pointer.
extension type const LibGhosttyHandle._(int value) {
  const LibGhosttyHandle.fromAddress(int value) : this._(value);
}

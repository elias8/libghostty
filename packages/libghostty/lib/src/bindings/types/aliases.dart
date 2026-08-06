import 'dart:typed_data';

import '../../ffi/libghostty_enums.g.dart';
import 'color.dart';

/// Cell wide property.
///
/// Describes the width behavior of a cell.
typedef CellWidth = CellWide;

/// Visual style of the cursor.
typedef CursorShape = RenderStateCursorVisualStyle;

/// Mouse tracking mode.
typedef MouseTracking = MouseTrackingMode;

/// Semantic content type of a cell.
///
/// Set by semantic prompt sequences (OSC 133) to distinguish between
/// command output, user input, and shell prompt text.
typedef SemanticContent = CellSemanticContent;

/// Row semantic prompt state.
///
/// Indicates whether any cells in a row are part of a shell prompt,
/// as reported by OSC 133 sequences.
typedef SemanticPrompt = RowSemanticPrompt;

/// Underline style types.
typedef UnderlineStyle = SgrUnderline;

typedef ValueGetter<T> = T Function();
typedef ValueSetter<T> = void Function(T value);
typedef VoidCallback = void Function();

/// One binary-safe representation in an atomic clipboard write.
///
/// [mime] identifies the representation and [data] contains its decoded
/// bytes. The bytes are owned by Dart and remain valid after the callback
/// returns.
typedef ClipboardContent = ({String mime, Uint8List data});

/// A protocol-neutral request to replace or clear clipboard contents.
///
/// Every entry in [contents] represents the same logical value and should be
/// committed atomically. An empty list requests that [location] be cleared.
typedef ClipboardWrite = ({
  ClipboardLocation location,
  List<ClipboardContent> contents,
});

/// Handles an atomic clipboard write requested by terminal content.
///
/// The return value reports the outcome of committing the complete request.
/// Protocols without acknowledgements may ignore it.
typedef ClipboardWriteCallback =
    ClipboardWriteResult Function(ClipboardWrite write);

/// A desktop notification requested by terminal content.
///
/// Both strings are owned by Dart and remain valid after the callback returns.
typedef DesktopNotification = ({String title, String body});

/// Handles a desktop notification requested by terminal content.
typedef DesktopNotificationCallback = void Function(DesktopNotification value);

/// Progress state requested by terminal content.
///
/// [progress] is a percentage from 0 through 100 when the protocol provides
/// one, and null otherwise.
typedef TerminalProgress = ({TerminalProgressState state, int? progress});

/// Handles a progress state requested by terminal content.
typedef TerminalProgressCallback = void Function(TerminalProgress value);

/// An untracked grid reference value.
///
/// The value follows libghostty's untracked grid-reference lifetime rules and
/// is valid only until the next mutating operation on the terminal that
/// produced it.
typedef RawGridRef = ({int node, int x, int y});

/// A selection range addressed by untracked grid-reference values.
///
/// `rectangle` indicates a rectangular block selection rather than a linear
/// text range.
typedef RawSelection = ({RawGridRef start, RawGridRef end, bool rectangle});

/// Terminal dimensions in cells and pixels.
///
/// `cols` and `rows` describe the active grid. `widthPx` and `heightPx`
/// describe its total pixel extent and are zero when no pixel size has been
/// configured.
typedef TerminalGeometry = ({int cols, int rows, int widthPx, int heightPx});

/// Render-state dimensions and dirty state returned by one batched query.
typedef RawRenderStateSummary = ({int cols, int rows, RenderStateDirty dirty});

/// Complete cursor data from one render-state snapshot query.
///
/// The viewport coordinates and wide-tail flag are meaningful only when
/// `inViewport` is true.
typedef RawRenderStateCursor = ({
  RenderStateCursorVisualStyle visualStyle,
  bool visible,
  bool blinking,
  bool passwordInput,
  bool inViewport,
  int viewportX,
  int viewportY,
  bool viewportWideTail,
});

/// Current render row data captured in one boundary query.
typedef RawRowIteratorSummary = ({bool dirty, int rawRow});

/// Scalar row metadata captured in one boundary query.
typedef RawRowSummary = ({
  bool wrap,
  bool wrapContinuation,
  bool grapheme,
  bool styled,
  bool hyperlink,
  RowSemanticPrompt semanticPrompt,
  bool kittyVirtualPlaceholder,
});

/// Current render cell data captured in one boundary query.
typedef RawRowCellsSummary = ({int rawCell, int graphemeLen, bool selected});

/// Scalar cell metadata captured in one boundary query.
typedef RawCellSummary = ({int codepoint, int styleId, CellWide wide});

/// Readable selection gesture state captured in one boundary query.
typedef RawSelectionGestureState = ({
  int clickCount,
  bool dragged,
  SelectionGestureAutoscroll autoscroll,
  SelectionGestureBehavior behavior,
  RawGridRef? anchor,
});

/// Callback invoked for each internal libghostty log message, after the
/// scope and message byte slices have been decoded to Dart strings.
typedef SysLogCallback =
    void Function(SysLogLevel level, String scope, String message);

/// An image decoded from PNG into top-to-bottom RGBA pixel bytes.
typedef DecodedImage = ({int width, int height, Uint8List rgba});

/// Callback that decodes PNG bytes to RGBA pixels.
///
/// Invoked by libghostty for every Kitty graphics payload received in
/// PNG form. Returning null signals a decode failure; the library
/// rejects the payload and no image is stored.
typedef PngDecoder = DecodedImage? Function(Uint8List pngBytes);

/// An X11 color name recognized by Ghostty's color parser.
typedef X11ColorName = ({String name, RgbColor color});

/// Raw placement metadata read from a Kitty graphics placement
/// iterator.
///
/// Sub-cell offsets and source rectangles are in pixels. `columns` and
/// `rows` may be zero when the protocol leaves the grid extent implicit
/// (the size is then derived from the image). `z` is signed; see
/// [KittyPlacementLayer] for how it maps to paint order.
typedef RawPlacement = ({
  int imageId,
  int placementId,
  bool isVirtual,
  int xOffset,
  int yOffset,
  int sourceX,
  int sourceY,
  int sourceWidth,
  int sourceHeight,
  int columns,
  int rows,
  int z,
});

/// Resolved rendering geometry for a placement, combining rendered
/// pixel size, grid extent, viewport-relative position, and the
/// clamped source rectangle.
///
/// `viewportCol`/`viewportRow` are meaningful only when
/// `viewportVisible` is true. Source rectangle fields have the
/// protocol's "0 means full image" semantics already applied and are
/// clamped to the image bounds.
typedef RawPlacementRenderInfo = ({
  int pixelWidth,
  int pixelHeight,
  int gridCols,
  int gridRows,
  int viewportCol,
  int viewportRow,
  bool viewportVisible,
  int sourceX,
  int sourceY,
  int sourceWidth,
  int sourceHeight,
});

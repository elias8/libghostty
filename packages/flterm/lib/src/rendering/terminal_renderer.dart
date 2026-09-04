import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:libghostty/libghostty.dart';
import 'package:meta/meta.dart';

import '../foundation.dart';
import '../links/link_snapshot.dart';
import 'atlas/atlas_config.dart';
import 'atlas_pool.dart';
import 'frame_source.dart';
import 'paint_state.dart';
import 'render_pipeline.dart';

/// Renders a terminal screen with cell backgrounds, styled text, cursors,
/// and selection overlays.
///
/// This is the core rendering widget used internally by [TerminalView].
/// It owns a [TerminalRenderBox] that orchestrates grid measurement, geometry
/// intent reporting, frame sync, and a paint stack. The controller, not the
/// renderer, validates and commits resize intents to the terminal engine.
///
/// Sizing is determined by the parent constraints and cell metrics: the
/// widget computes how many columns and rows fit, then sizes itself to
/// exactly that grid. When the grid, physical cell dimensions, or surface
/// padding change, [onGeometryChanged] reports the geometry intent to the
/// owner.
///
/// ```dart
/// TerminalRenderer(
///   frameSource: frameSource,
///   theme: TerminalTheme.dark(),
///   metrics: measureCellMetrics(fontFamily: 'monospace', fontSize: 14),
///   offset: ViewportOffset.zero(),
///   focused: true,
/// )
/// ```
@internal
final class TerminalRenderer extends LeafRenderObjectWidget {
  /// Supplies the terminal and publishes frame and viewport changes.
  final FrameSource frameSource;

  /// Visual style applied to the terminal.
  ///
  /// When changed, the glyph atlas is updated if font properties changed and
  /// a full repaint is scheduled. The owning view applies terminal colors.
  final TerminalTheme theme;

  /// Cell pixel dimensions used for grid sizing and coordinate conversion.
  ///
  /// When changed, the glyph atlas is cleared and layout is recalculated.
  /// A geometry change triggers [onGeometryChanged].
  final CellMetrics metrics;

  /// Padding around the rendered terminal surface in logical pixels.
  ///
  /// This is carried to the resize callback so surface-space mouse
  /// coordinates can be converted consistently with the terminal engine's
  /// physical surface size.
  final EdgeInsets surfacePadding;

  /// Scroll offset provided by a [Scrollable] ancestor.
  ///
  /// At `pixels == 0`, the oldest scrollback row is visible.
  /// At `pixels == maxScrollExtent`, the live screen is visible.
  final ViewportOffset offset;

  /// Whether the terminal view currently has focus.
  ///
  /// The owning view supplies this value from its [FocusNode]. Changes
  /// trigger a repaint to update cursor appearance.
  final bool focused;

  /// Whether the cursor blink is currently in the visible phase.
  ///
  /// When false, the cursor and blinking text (SGR 5) are hidden.
  /// Toggled by a timer in [TerminalView].
  final bool blinkVisible;

  /// IME preedit text to draw at the cursor before it is committed.
  final String preeditText;

  /// Visible link styling state prepared by the view layer.
  final LinkSnapshot linkSnapshot;

  /// Reports terminal geometry changes discovered during layout.
  ///
  /// The callback receives the complete measured geometry. The owner must
  /// apply the transaction before notifying its backend.
  final ValueChanged<SurfaceMeasurement> onGeometryChanged;

  /// Device pixel ratio of the Flutter view hosting this renderer.
  final double devicePixelRatio;

  /// Internal atlas pool used to share compatible rendering state.
  final AtlasPool atlasPool;

  /// Requests a terminal viewport row derived from Flutter scroll layout.
  final ValueChanged<int> onViewportRowChanged;

  /// Monotonically increasing request for an accessible viewport snapshot.
  final int semanticsGeneration;

  /// Receives accessible text after terminal state has synchronized for paint.
  final ValueChanged<String>? onSemanticsText;

  const TerminalRenderer({
    super.key,
    required this.frameSource,
    required this.theme,
    required this.metrics,
    this.surfacePadding = EdgeInsets.zero,
    required this.offset,
    required this.focused,
    required this.atlasPool,
    this.devicePixelRatio = 1,
    this.blinkVisible = true,
    this.preeditText = '',
    this.linkSnapshot = .empty,
    required this.onGeometryChanged,
    required this.onViewportRowChanged,
    this.semanticsGeneration = 0,
    this.onSemanticsText,
  });

  @override
  TerminalRenderBox createRenderObject(BuildContext context) {
    return TerminalRenderBox(
      theme: theme,
      offset: offset,
      metrics: metrics,
      surfacePadding: surfacePadding,
      frameSource: frameSource,
      atlasPool: atlasPool,
      devicePixelRatio: devicePixelRatio,
      onGeometryChanged: onGeometryChanged,
      onViewportRowChanged: onViewportRowChanged,
      blinkVisible: blinkVisible,
      preeditText: preeditText,
      linkSnapshot: linkSnapshot,
      focused: focused,
      semanticsGeneration: semanticsGeneration,
      onSemanticsText: onSemanticsText,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<Terminal>('terminal', frameSource.terminal))
      ..add(DiagnosticsProperty<TerminalTheme>('theme', theme))
      ..add(DiagnosticsProperty<CellMetrics>('metrics', metrics))
      ..add(DiagnosticsProperty<ViewportOffset>('offset', offset))
      ..add(
        FlagProperty(
          'blinkVisible',
          value: blinkVisible,
          ifTrue: 'blink visible',
        ),
      )
      ..add(StringProperty('preeditText', preeditText, defaultValue: ''));
  }

  @override
  void updateRenderObject(
    BuildContext context,
    TerminalRenderBox renderObject,
  ) {
    renderObject
      ..frameSource = frameSource
      ..theme = theme
      ..atlasPool = atlasPool
      ..offset = offset
      ..metrics = metrics
      ..surfacePadding = surfacePadding
      ..devicePixelRatio = devicePixelRatio
      ..onGeometryChanged = onGeometryChanged
      ..onViewportRowChanged = onViewportRowChanged
      ..focused = focused
      ..blinkVisible = blinkVisible
      ..preeditText = preeditText
      ..linkSnapshot = linkSnapshot
      ..semanticsGeneration = semanticsGeneration
      ..onSemanticsText = onSemanticsText;
  }
}

/// Render object orchestrating terminal layout, state sync, and painting.
///
/// Three phases per frame:
///
/// 1. **Layout**: computes grid size from constraints and [CellMetrics],
///    configures the glyph atlas for the current DPR, reports geometry intent
///    when measurements change, and updates scroll extents.
///
/// 2. **Sync** (start of paint): snapshots terminal cells, resolves colors
///    (including OSC 10/11 overrides, bold-is-bright, inverse, faint),
///    builds frame data for text/backgrounds/decorations, resolves
///    the cursor cell glyph, and collects Kitty graphics placements.
///
/// 3. **Paint**: delegates to a paint stack that owns painter instances,
///    Kitty image snapshots, and z-order.
///
/// Created and managed by [TerminalRenderer]. Not intended for direct use.
@internal
final class TerminalRenderBox extends RenderBox {
  final PaintState _paintState;
  late final RenderPipeline _pipeline;

  var _applyingViewportIntent = false;
  var _cellHeightPx = 0;
  var _cellWidthPx = 0;
  double _devicePixelRatio;
  FrameSource _frameSource;
  late AtlasLease _atlasLease;
  var _lastCellHeight = 0.0;
  var _lastCellWidth = 0.0;
  var _lastDevicePixelRatio = 0.0;
  var _lastScrollbackRows = 0;
  var _lastSurfacePadding = EdgeInsets.zero;
  LinkSnapshot _linkSnapshot;
  var _needsFrameSync = false;
  ViewportOffset _offset;
  ValueChanged<SurfaceMeasurement> _onGeometryChanged;
  ValueChanged<int> _onViewportRowChanged;
  int? _pendingViewportRow;
  var _performingLayout = false;
  var _preeditText = '';
  bool? _primaryStickToBottom;
  AtlasPool _atlasPool;
  int _semanticsGeneration;
  late int _capturedSemanticsGeneration;
  ValueChanged<String>? _onSemanticsText;
  var _stickToBottom = true;
  var _surfacePadding = EdgeInsets.zero;

  TerminalRenderBox({
    required this._frameSource,
    required TerminalTheme theme,
    required CellMetrics metrics,
    EdgeInsets surfacePadding = EdgeInsets.zero,
    required this._offset,
    required bool focused,
    required this._atlasPool,
    required this._devicePixelRatio,
    bool blinkVisible = true,
    this._linkSnapshot = .empty,
    this._preeditText = '',
    required this._onGeometryChanged,
    required this._onViewportRowChanged,
    int semanticsGeneration = 0,
    ValueChanged<String>? onSemanticsText,
  }) : _surfacePadding = surfacePadding,
       _lastSurfacePadding = surfacePadding,
       _semanticsGeneration = semanticsGeneration,
       _capturedSemanticsGeneration = onSemanticsText == null
           ? semanticsGeneration
           : semanticsGeneration - 1,
       _onSemanticsText = onSemanticsText,
       _paintState = PaintState(theme, metrics)
         ..blinkVisible = blinkVisible
         ..cursorFocused = focused {
    _atlasLease = _atlasPool.acquireAtlas(
      .fromTheme(
        theme: theme,
        metrics: metrics,
        devicePixelRatio: _devicePixelRatio,
      ),
    );
    final atlas = _atlasLease.atlas;
    _pipeline = RenderPipeline(
      atlas: atlas,
      state: _paintState,
      onImageReady: _markFrameDirty,
    );
  }

  Terminal get _terminal => _frameSource.terminal;

  set surfacePadding(EdgeInsets value) {
    if (_surfacePadding == value) return;
    _surfacePadding = value;
    markNeedsLayout();
  }

  bool get blinkVisible => _paintState.blinkVisible;

  set blinkVisible(bool value) {
    if (_paintState.blinkVisible == value) return;
    _paintState.blinkVisible = value;
    _pipeline.markAllRowsDirty();
    _pipeline.refreshCursorGlyph();
    markNeedsPaint();
  }

  set preeditText(String value) {
    if (_preeditText == value) return;
    _preeditText = value;
    markNeedsPaint();
  }

  set linkSnapshot(LinkSnapshot value) {
    if (_linkSnapshot == value) return;
    final previous = _linkSnapshot;
    _linkSnapshot = value;
    if (identical(previous.matches, value.matches)) {
      _markLinkRowsDirty(previous.highlighted);
      _markLinkRowsDirty(value.highlighted);
    } else {
      _markLinkSnapshotRowsDirty(previous);
      _markLinkSnapshotRowsDirty(value);
    }
    markNeedsPaint();
  }

  @override
  bool get isRepaintBoundary => true;

  /// Current terminal input caret rect in this render box's local coordinates.
  Rect get textInputCaretRect {
    final metrics = _paintState.metrics;
    final rows = _paintState.rows;
    final cols = _paintState.cols;
    final cursor = _paintState.cursor;
    if (rows <= 0 || cols <= 0 || !cursor.viewportHasValue) {
      return Offset.zero & Size(metrics.cellWidth, metrics.cellHeight);
    }

    final row = cursor.viewportY.clamp(0, rows - 1);
    final rawCol = cursor.wideTail && cursor.viewportX > 0
        ? cursor.viewportX - 1
        : cursor.viewportX;
    final col = rawCol.clamp(0, cols - 1);
    return metrics.cellRect(Position(row: row, col: col), .zero);
  }

  /// Current terminal composing rect in this render box's local coordinates.
  Rect get textInputComposingRect => textInputCaretRect;

  void _markLinkRowsDirty(CellRange? range) {
    if (range == null) return;
    final rows = _paintState.rows;
    if (rows <= 0) return;

    var start = range.start.row;
    var end = range.end.row + 1;
    if (start < 0) start = 0;
    if (end > rows) end = rows;
    if (start >= end) return;

    _pipeline.markRowsDirty(start, end);
  }

  void _markLinkSnapshotRowsDirty(LinkSnapshot snapshot) {
    _markLinkRowsDirty(snapshot.highlighted);
    for (final match in snapshot.matches) {
      _markLinkRowsDirty(match.link.range);
    }
  }

  set metrics(CellMetrics value) {
    if (_paintState.metrics == value) return;
    _paintState.metrics = value;
    markNeedsLayout();
  }

  set offset(ViewportOffset value) {
    if (_offset == value) return;
    if (attached) _offset.removeListener(_onScroll);
    _offset = value;
    if (attached) _offset.addListener(_onScroll);
    markNeedsLayout();
  }

  set onGeometryChanged(ValueChanged<SurfaceMeasurement> value) =>
      _onGeometryChanged = value;

  set devicePixelRatio(double value) {
    if (_devicePixelRatio == value) return;
    _devicePixelRatio = value;
    markNeedsLayout();
  }

  set onViewportRowChanged(ValueChanged<int> value) =>
      _onViewportRowChanged = value;

  set onSemanticsText(ValueChanged<String>? value) {
    if (_onSemanticsText == value) return;
    _onSemanticsText = value;
    if (value != null) {
      _capturedSemanticsGeneration = _semanticsGeneration - 1;
      markNeedsPaint();
    }
  }

  set semanticsGeneration(int value) {
    if (_semanticsGeneration == value) return;
    _semanticsGeneration = value;
    if (_onSemanticsText != null) markNeedsPaint();
  }

  bool get focused => _paintState.cursorFocused;

  set focused(bool value) {
    if (_paintState.cursorFocused == value) return;
    _paintState.cursorFocused = value;
    _pipeline.refreshCursorGlyph();
    markNeedsPaint();
  }

  set atlasPool(AtlasPool value) {
    if (identical(value, _atlasPool)) return;

    _atlasPool = value;
    final atlasChanged = _acquireAtlasForCurrentConfig(force: true);
    if (atlasChanged) _markFrameDirty();
  }

  set frameSource(FrameSource value) {
    if (identical(_frameSource, value)) return;
    if (attached) _frameSource.removeListener(_onFrameChanged);
    final terminalChanged = !identical(_terminal, value.terminal);
    _frameSource = value;
    if (attached) _frameSource.addListener(_onFrameChanged);
    if (terminalChanged) {
      _stickToBottom = true;
      _primaryStickToBottom = null;
      _cellWidthPx = 0;
      _cellHeightPx = 0;
      _pendingViewportRow = null;
    }
    _needsFrameSync = true;
    markNeedsLayout();
  }

  TerminalTheme get theme => _paintState.theme;

  /// Updates the theme, clearing the atlas only if font properties changed.
  ///
  /// Color-only changes (palette, foreground, background) use markNeedsPaint
  /// which repaints with the existing atlas. Font changes (size, weight,
  /// family) use markNeedsLayout which reconfigures the atlas, re-measures
  /// the grid, and pre-seeds glyphs.
  set theme(TerminalTheme value) {
    if (_paintState.theme == value) return;
    final oldTheme = _paintState.theme;
    final fontChanged =
        oldTheme.fontSize != value.fontSize ||
        oldTheme.fontWeight != value.fontWeight ||
        oldTheme.fontFamily != value.fontFamily ||
        !_listEquals(oldTheme.fontFamilyFallback, value.fontFamilyFallback);
    _paintState.updateTheme(value);
    _pipeline.markAllRowsDirty();
    _needsFrameSync = true;

    if (fontChanged) {
      markNeedsLayout();
    } else {
      markNeedsPaint();
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _offset.addListener(_onScroll);
    _frameSource.addListener(_onFrameChanged);
    markNeedsLayout();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(IntProperty('cols', _paintState.cols))
      ..add(IntProperty('rows', _paintState.rows))
      ..add(DiagnosticsProperty<TerminalTheme>('theme', _paintState.theme))
      ..add(DiagnosticsProperty<CellMetrics>('metrics', _paintState.metrics))
      ..add(
        FlagProperty(
          'blinkVisible',
          value: _paintState.blinkVisible,
          ifTrue: 'cursor visible',
        ),
      );
  }

  @override
  void detach() {
    _offset.removeListener(_onScroll);
    _frameSource.removeListener(_onFrameChanged);
    super.detach();
  }

  @override
  void dispose() {
    _paintState.rows = 0;
    _paintState.cols = 0;
    _pipeline.dispose();
    _atlasLease.release();
    super.dispose();
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    _syncFrameState();
    if (_onSemanticsText != null &&
        _capturedSemanticsGeneration != _semanticsGeneration) {
      _capturedSemanticsGeneration = _semanticsGeneration;
      _onSemanticsText!(_pipeline.semanticsText());
    }

    final canvas = context.canvas;

    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    _pipeline.paint(canvas);
    canvas.restore();
  }

  @override
  void performLayout() {
    _performingLayout = true;
    try {
      final maxW = constraints.hasBoundedWidth ? constraints.maxWidth : 0.0;
      final maxH = constraints.hasBoundedHeight ? constraints.maxHeight : 0.0;
      final (newCols, newRows) = _paintState.metrics.gridSize(maxW, maxH);

      size = constraints.constrain(
        Size(
          newCols * _paintState.metrics.cellWidth,
          newRows * _paintState.metrics.cellHeight,
        ),
      );

      final dpr = _devicePixelRatio;
      final atlasReconfigured = _acquireAtlasForCurrentConfig(dpr: dpr);

      final gridChanged =
          newCols != _paintState.cols || newRows != _paintState.rows;
      final cellWidthPx = (_paintState.metrics.cellWidth * dpr).round();
      final cellHeightPx = (_paintState.metrics.cellHeight * dpr).round();
      final logicalMetricsChanged =
          _paintState.metrics.cellWidth != _lastCellWidth ||
          _paintState.metrics.cellHeight != _lastCellHeight;
      final devicePixelRatioChanged = dpr != _lastDevicePixelRatio;
      final geometryChanged =
          gridChanged ||
          cellWidthPx != _cellWidthPx ||
          cellHeightPx != _cellHeightPx ||
          logicalMetricsChanged ||
          devicePixelRatioChanged ||
          _surfacePadding != _lastSurfacePadding;
      if (_paintState.devicePixelRatio != dpr) {
        _paintState.devicePixelRatio = dpr;
      }
      if (geometryChanged) {
        _paintState.cols = newCols;
        _paintState.rows = newRows;
        if (newCols > 0 && newRows > 0) {
          if (gridChanged) _pipeline.configureGrid(newRows, newCols);
          _onGeometryChanged(
            SurfaceMeasurement(
              cols: newCols,
              rows: newRows,
              cellWidth: _paintState.metrics.cellWidth,
              cellHeight: _paintState.metrics.cellHeight,
              paddingLeft: _surfacePadding.left,
              paddingRight: _surfacePadding.right,
              paddingTop: _surfacePadding.top,
              paddingBottom: _surfacePadding.bottom,
              devicePixelRatio: dpr,
            ),
          );
        }
        _cellWidthPx = cellWidthPx;
        _cellHeightPx = cellHeightPx;
        _lastCellWidth = _paintState.metrics.cellWidth;
        _lastCellHeight = _paintState.metrics.cellHeight;
        _lastDevicePixelRatio = dpr;
      }
      _lastSurfacePadding = _surfacePadding;

      _syncScrollLayout();

      // Grid changes invalidate every row's sprite slot layout. Atlas
      // rebinding invalidates atlas references inside the pipeline.
      if (gridChanged) _pipeline.markAllRowsDirty();

      if (geometryChanged || atlasReconfigured) _markFrameDirty();
    } finally {
      _performingLayout = false;
    }
  }

  bool _acquireAtlasForCurrentConfig({double? dpr, bool force = false}) {
    final config = AtlasConfig.fromTheme(
      theme: _paintState.theme,
      metrics: _paintState.metrics,
      devicePixelRatio: dpr ?? _devicePixelRatio,
    );
    if (!force && config == _atlasLease.config) return false;

    final previousLease = _atlasLease;
    _atlasLease = _atlasPool.acquireAtlas(config);
    _pipeline.bindAtlas(_atlasLease.atlas);
    previousLease.release();
    return true;
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _markFrameDirty() {
    _needsFrameSync = true;
    markNeedsPaint();
  }

  void _onScroll() {
    if (_performingLayout) return;
    if (_paintState.rows == 0 || _paintState.metrics.cellHeight <= 0) return;

    final scrollbar = _terminal.scrollbar;
    final scrollbackLen = scrollbar.total - scrollbar.visible;
    if (scrollbackLen <= 0) return;

    final cellHeight = _paintState.metrics.cellHeight;
    final maxExtent = scrollbackLen * cellHeight;
    final pixels = _offset.pixels.clamp(0.0, maxExtent);

    _stickToBottom = maxExtent <= 0 || pixels >= maxExtent - cellHeight;

    final targetRow = (pixels / cellHeight).floor();
    if (targetRow == scrollbar.offset) return;

    _applyingViewportIntent = true;
    try {
      _onViewportRowChanged(targetRow);
    } finally {
      _applyingViewportIntent = false;
    }
    _markFrameDirty();
  }

  // Handles terminal change notifications.
  //
  // When scrollback length changes, a layout pass is needed because scroll
  // extents must be recalculated. For normal output (same scrollback
  // length), only a repaint is needed.
  void _onFrameChanged() {
    if (_paintState.rows == 0 || _performingLayout) return;
    if (_applyingViewportIntent) {
      _markFrameDirty();
      return;
    }

    final scrollbar = _terminal.scrollbar;
    final scrollbackLen = scrollbar.total - scrollbar.visible;
    final flutterRow = (_offset.pixels / _paintState.metrics.cellHeight)
        .floor();
    if (flutterRow != scrollbar.offset) {
      _pendingViewportRow = scrollbar.offset;
      _stickToBottom = scrollbackLen <= 0 || scrollbar.offset >= scrollbackLen;
    }

    if (_terminal.scrollbackRows != _lastScrollbackRows ||
        _pendingViewportRow != null) {
      _needsFrameSync = true;
      markNeedsLayout();
      return;
    }

    _markFrameDirty();
  }

  // Maintains scroll position and content dimensions.
  //
  // "Stick to bottom" keeps the viewport pinned to the latest output,
  // which is the normal mode when the user hasn't scrolled up. Once the
  // user scrolls away from the bottom, new output no longer forces the
  // viewport down. Stick-to-bottom re-engages when the user scrolls
  // back to within one cell of the bottom edge.
  void _syncScrollLayout() {
    _offset.applyViewportDimension(size.height);

    if (_terminal.activeScreen == .alternate) {
      _primaryStickToBottom ??= _stickToBottom;
      _pendingViewportRow = null;
      _offset.applyContentDimensions(0, 0);
      _lastScrollbackRows = 0;
      _stickToBottom = true;
      return;
    }

    final primaryStickToBottom = _primaryStickToBottom;
    if (primaryStickToBottom != null) {
      _stickToBottom = primaryStickToBottom;
      _primaryStickToBottom = null;
    }

    final scrollbar = _terminal.scrollbar;
    final scrollbackLen = scrollbar.total - scrollbar.visible;
    final cellHeight = _paintState.metrics.cellHeight;
    final maxExtent = scrollbackLen * cellHeight;

    final pendingViewportRow = _pendingViewportRow;
    _pendingViewportRow = null;
    if (pendingViewportRow != null) {
      final targetPixels =
          pendingViewportRow.clamp(0, scrollbackLen) * cellHeight;
      final correction = targetPixels - _offset.pixels;
      if (correction.abs() > 0.01) _offset.correctBy(correction);
    }

    // Detect if the terminal was scrolled to bottom externally.
    if (!_stickToBottom &&
        scrollbackLen > 0 &&
        scrollbar.offset >= scrollbackLen) {
      _stickToBottom = true;
    }

    if (_stickToBottom && maxExtent > 0) {
      final correction = maxExtent - _offset.pixels;
      if (correction.abs() > 0.01) _offset.correctBy(correction);
      if (scrollbar.offset < scrollbackLen) {
        _onViewportRowChanged(scrollbackLen);
      }
    }
    _offset.applyContentDimensions(0, maxExtent);
    _lastScrollbackRows = scrollbackLen;
    _stickToBottom = maxExtent <= 0 || _offset.pixels >= maxExtent - cellHeight;
  }

  // Syncs terminal state into paint-ready frame buffers.
  void _syncFrameState() {
    if (_paintState.rows == 0) return;

    final terminalDirty = _needsFrameSync;
    _needsFrameSync = false;
    _pipeline.sync(
      _terminal,
      terminalDirty: terminalDirty,
      preeditText: _preeditText,
      linkSnapshot: _linkSnapshot,
    );
  }
}

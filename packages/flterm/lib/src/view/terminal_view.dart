import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:libghostty/libghostty.dart' show GridRef, Position, Selection;

import '../controller/terminal_controller.dart';
import '../foundation.dart';
import '../input/interaction_region.dart';
import '../links/link_interaction.dart';
import '../links/link_settings.dart';
import '../rendering.dart';
import '../rendering/atlas_pool.dart';
import 'cursor_blink.dart';
import 'shortcut_scope.dart';
import 'terminal_scope.dart';
import 'terminal_scroll_controller.dart';
import 'view_attachment.dart';

part 'terminal_view_geometry.dart';

/// Displays a terminal and handles user interaction.
///
/// Pair with a [TerminalController] to create a working terminal. The
/// controller owns the terminal state; the view handles rendering,
/// scrolling, gestures, focus, and keyboard shortcuts.
///
/// Fills the available space and computes the grid dimensions (columns
/// and rows) from the font metrics and pixel area. A controller can be attached
/// to only one view at a time. The view releases that attachment when removed
/// or when [controller] changes, but it never disposes the controller.
///
/// ```dart
/// final controller = TerminalController()
///   ..onOutput = (bytes) => pty.write(bytes);
///
/// TerminalView(
///   controller: controller,
///   theme: TerminalTheme.dark(),
///   autofocus: true,
/// );
/// ```
class TerminalView extends StatefulWidget {
  /// The controller that owns the terminal instance.
  ///
  /// Can be swapped at runtime; the view releases the old controller and binds
  /// its local focus, input, scroll, and rendering adapters to the new one. The
  /// new controller must not already be attached to another [TerminalView].
  final TerminalController controller;

  /// Visual style. Defaults to [TerminalTheme.dark()].
  ///
  /// Changing the font family or size recalculates cell metrics and
  /// may resize the grid.
  final TerminalTheme? theme;

  /// Focus node for this terminal. Created internally when null.
  ///
  /// Supply your own to manage focus externally (e.g. for tab switching
  /// or split pane navigation).
  final FocusNode? focusNode;

  /// Whether to request focus when first inserted into the tree.
  final bool autofocus;

  /// Whether to show the soft keyboard when focus is gained.
  ///
  /// Focus and keyboard state are owned by this view. When false, taps and
  /// programmatic focus can still focus the terminal, but a focus gain does not
  /// request a platform text-input connection.
  final bool showKeyboard;

  /// When to auto-hide the mouse cursor.
  final MouseAutoHide mouseAutoHide;

  /// Controls which selection gestures are enabled and how they behave.
  final TerminalGestureSettings gestureSettings;

  /// Controls terminal link detection, styling, and activation callbacks.
  final LinkSettings linkSettings;

  /// Padding around the terminal grid.
  ///
  /// Filled with the theme background color. The grid is sized from
  /// the remaining space after padding. Mouse coordinates are translated
  /// through this inset when reported to terminal applications. Defaults to
  /// 8px on all sides.
  final EdgeInsets padding;

  /// Scroll physics for scrollback and terminal scroll gestures.
  ///
  /// The platform default is used when null. The same physics controls touch
  /// and trackpad momentum when gestures are forwarded to a terminal program.
  final ScrollPhysics? scrollPhysics;

  /// Scroll controller for programmatic scrollback access.
  ///
  /// Created internally when null.
  final TerminalScrollController? scrollController;

  /// Builds application-defined content over the complete terminal surface.
  ///
  /// The builder receives cell-aware geometry in the overlay's coordinate
  /// system. Use it for any application-defined content that belongs over the
  /// terminal, including controls, annotations, status UI, or effects.
  /// It rebuilds when the overlay constraints, search state, or terminal
  /// viewport changes. The returned subtree owns any additional state, layout,
  /// input, and semantics.
  ///
  /// ```dart
  /// overlayBuilder: (context, geometry) => Stack(
  ///   children: [
  ///     Positioned(
  ///       left: geometry.gridBounds.left,
  ///       top: geometry.gridBounds.top,
  ///       child: const TerminalStatusBadge(),
  ///     ),
  ///   ],
  /// ),
  /// ```
  final TerminalOverlayBuilder? overlayBuilder;

  /// Shortcut bindings merged over platform defaults.
  ///
  /// Defaults: Command+C/V/A/K on macOS and iOS,
  /// Control+Shift+C/V/A/K on Linux and Fuchsia, and Control+C/V/A/K on
  /// Windows and Android. Custom entries with the same activator replace the
  /// corresponding default.
  final Map<ShortcutActivator, Intent>? shortcuts;

  /// Raw TTF/OTF font file bytes for exact metric extraction.
  ///
  /// When provided, takes priority over automatic font resolution. The
  /// font's `post` and `OS/2` tables are parsed to get exact underline
  /// and strikethrough thickness and position values.
  ///
  /// When null (the default), the widget automatically resolves font
  /// data by searching asset bundles and system font directories via
  /// [FontDataResolver]. If auto-resolution also fails, heuristic
  /// fallbacks are used.
  final Uint8List? fontData;

  const TerminalView({
    super.key,
    required this.controller,
    this.theme,
    this.fontData,
    this.focusNode,
    this.shortcuts,
    this.scrollPhysics,
    this.scrollController,
    this.overlayBuilder,
    this.autofocus = false,
    this.showKeyboard = true,
    this.padding = const .all(8),
    this.mouseAutoHide = .onInput,
    this.linkSettings = const LinkSettings(),
    this.gestureSettings = const TerminalGestureSettings(),
  });

  @override
  State<TerminalView> createState() => _TerminalViewState();
}

final class _TerminalViewState extends State<TerminalView>
    with WidgetsBindingObserver {
  final _rendererKey = GlobalKey();
  final _links = LinkInteraction();
  final _cursorBlink = CursorBlink();
  final _mouseCursorHidden = ValueNotifier(false);
  late final _mouseInteraction = Listenable.merge([_links, _mouseCursorHidden]);

  late ViewAttachment _attachment;
  var _devicePixelRatio = 1.0;
  late FocusNode _focusNode;
  late ScrollPhysics _gestureScrollPhysics;
  late CellMetrics _metrics;
  var _ownsFocusNode = false;
  var _ownsScrollController = false;
  Uint8List? _resolvedFontData;
  late TerminalScrollController _scrollController;
  late TerminalTheme _theme;
  int? _viewId;

  TerminalController get _controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    final atlasPool = terminalScopeAtlasPoolOf(context);
    if (atlasPool != null) return _build(atlasPool);

    return TerminalScope(
      child: Builder(
        builder: (context) => _build(terminalScopeAtlasPoolOf(context)!),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateGestureScrollPhysics();

    final viewId = View.of(context).viewId;
    if (_viewId != viewId) {
      _viewId = viewId;
      _attachment.attach(_focusNode, _scrollController, viewId: viewId);
    }

    final devicePixelRatio = View.of(context).devicePixelRatio;
    if (_devicePixelRatio == devicePixelRatio) return;
    _devicePixelRatio = devicePixelRatio;
    _metrics = _measureMetrics();
    _links.cancel();
    _syncLinkInteraction();
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    final devicePixelRatio = View.of(context).devicePixelRatio;
    if (_devicePixelRatio == devicePixelRatio) return;
    setState(() {
      _devicePixelRatio = devicePixelRatio;
      _metrics = _measureMetrics();
    });
    _links.cancel();
    _syncLinkInteraction();
  }

  @override
  void didUpdateWidget(TerminalView oldWidget) {
    super.didUpdateWidget(oldWidget);

    final controllerChanged = widget.controller != oldWidget.controller;
    final focusNodeChanged = widget.focusNode != oldWidget.focusNode;
    final scrollControllerChanged =
        widget.scrollController != oldWidget.scrollController;

    if (controllerChanged) {
      _attachment.removeListener(_onControllerChanged);
      _attachment.dispose();
    } else if (focusNodeChanged) {
      _attachment.detach();
    }

    if (focusNodeChanged) {
      if (_ownsFocusNode) _focusNode.dispose();
      _focusNode = widget.focusNode ?? FocusNode();
      _ownsFocusNode = widget.focusNode == null;
    }

    if (scrollControllerChanged) {
      _scrollController.removeListener(_onScrollChanged);
      if (_ownsScrollController) _scrollController.dispose();
      _scrollController = widget.scrollController ?? TerminalScrollController();
      _ownsScrollController = widget.scrollController == null;
      _scrollController.addListener(_onScrollChanged);
    }

    if (widget.scrollPhysics != oldWidget.scrollPhysics) {
      _updateGestureScrollPhysics();
    }

    if (controllerChanged) {
      _attachment = ViewAttachment(_controller);
      _attachment.addListener(_onControllerChanged);
      _links.invalidateContent();
    }

    if (controllerChanged || focusNodeChanged || scrollControllerChanged) {
      _scrollController.activeScreen = _controller.activeScreen;
      _attachment.attach(_focusNode, _scrollController, viewId: _viewId!);
    }

    final oldTheme = _theme;
    final themeChanged = widget.theme != oldWidget.theme;
    if (themeChanged) {
      _theme = widget.theme ?? TerminalTheme.dark();
    }
    if (controllerChanged || themeChanged) _attachment.applyTheme(_theme);

    final fontDataChanged = widget.fontData != oldWidget.fontData;
    final fontFamilyChanged = _theme.fontFamily != oldTheme.fontFamily;
    if (fontFamilyChanged) _resolvedFontData = null;

    final fontMetricsChanged =
        fontDataChanged ||
        _theme.fontSize != oldTheme.fontSize ||
        _theme.fontWeight != oldTheme.fontWeight ||
        fontFamilyChanged ||
        _theme.fontFamilyFallback != oldTheme.fontFamilyFallback;
    if (fontMetricsChanged) {
      _metrics = _measureMetrics();
      _links.cancel();
    }

    if (themeChanged) {
      if (_theme.cursor.blinkInterval != oldTheme.cursor.blinkInterval) {
        _syncBlink();
      }
    }
    if (widget.fontData == null &&
        (fontFamilyChanged || (fontDataChanged && _resolvedFontData == null))) {
      unawaited(_resolveFontData(_theme.fontFamily));
    }

    _syncLinkInteraction();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cursorBlink.dispose();
    _mouseCursorHidden.dispose();
    _links.dispose();
    _attachment.removeListener(_onControllerChanged);
    _attachment.dispose();
    if (_ownsFocusNode) _focusNode.dispose();
    _scrollController.removeListener(_onScrollChanged);
    if (_ownsScrollController) _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _attachment = ViewAttachment(_controller);
    _focusNode = widget.focusNode ?? FocusNode();
    _ownsFocusNode = widget.focusNode == null;

    _theme = widget.theme ?? TerminalTheme.dark();
    _attachment.applyTheme(_theme);
    _metrics = _measureMetrics();

    if (widget.fontData == null) unawaited(_resolveFontData(_theme.fontFamily));

    _scrollController = widget.scrollController ?? TerminalScrollController();
    _ownsScrollController = widget.scrollController == null;
    _scrollController.activeScreen = _controller.activeScreen;
    _scrollController.addListener(_onScrollChanged);
    _attachment.addListener(_onControllerChanged);
    _syncLinkInteraction();
  }

  Widget _build(AtlasPool atlasPool) {
    return GestureDetector(
      behavior: .translucent,
      onTap: _attachment.requestFocus,
      child: ColoredBox(
        color: _theme.background.withValues(alpha: _theme.backgroundOpacity),
        child: Stack(
          fit: .expand,
          children: [
            Padding(
              padding: widget.padding,
              child: Focus(
                onKeyEvent: _handleKeyEvent,
                child: ShortcutScope(
                  onPaste: _handlePaste,
                  controller: _controller,
                  shortcuts: widget.shortcuts,
                  enableSelectAll: widget.gestureSettings.selectAllShortcut,
                  child: ListenableBuilder(
                    listenable: _attachment.interaction,
                    builder: (_, _) =>
                        _buildInteraction(atlasPool, _gestureScrollPhysics),
                  ),
                ),
              ),
            ),
            if (widget.overlayBuilder case final builder?)
              Positioned.fill(
                child: ListenableBuilder(
                  listenable: Listenable.merge([
                    _controller.search,
                    _attachment.viewportChanges,
                  ]),
                  builder: (context, _) => LayoutBuilder(
                    builder: (context, constraints) =>
                        builder(context, _geometryFor(constraints)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteraction(
    AtlasPool atlasPool,
    ScrollPhysics gestureScrollPhysics,
  ) {
    final interaction = _attachment.interaction.value;
    final scrollPhysics = interaction.activeScreen == .alternate
        ? const NeverScrollableScrollPhysics()
        : widget.scrollPhysics;
    final content = Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onFocusChange: _handleFocusChange,
      child: Scrollable(
        controller: _scrollController,
        physics: scrollPhysics,
        viewportBuilder: (_, offset) => InteractionRegion(
          theme: _theme,
          links: _links,
          metrics: _metrics,
          attachment: _attachment,
          interaction: interaction,
          settings: widget.gestureSettings,
          scrollPhysics: gestureScrollPhysics,
          scrollController: _scrollController,
          onLinkActivate: widget.linkSettings.onActivate,
          child: ListenableBuilder(
            listenable: _controller.search,
            builder: (context, _) {
              final search = _controller.search;
              final searchMatches = search.viewportMatches;
              final selectedSearchMatch = search.selectedMatch;
              return ListenableBuilder(
                listenable: Listenable.merge([
                  _focusNode,
                  _attachment.input,
                  _cursorBlink,
                  _links,
                ]),
                builder: (context, _) => TerminalRenderer(
                  key: _rendererKey,
                  theme: _theme,
                  offset: offset,
                  metrics: _metrics,
                  focused: _focusNode.hasFocus,
                  frameSource: _attachment.frameSource,
                  searchMatches: searchMatches,
                  selectedSearchMatch: selectedSearchMatch,
                  atlasPool: atlasPool,
                  surfacePadding: widget.padding,
                  devicePixelRatio: _devicePixelRatio,
                  preeditText: _attachment.input.preeditText,
                  blinkVisible: _cursorBlink.value,
                  linkSnapshot: _links.snapshot(),
                  onGeometryChanged: _handleResize,
                  onViewportRowChanged: _attachment.handleViewportRowChanged,
                ),
              );
            },
          ),
        ),
      ),
    );
    return ListenableBuilder(
      listenable: _mouseInteraction,
      child: content,
      builder: (context, child) => MouseRegion(
        onHover: _handleMouseHover,
        onExit: _handleMouseExit,
        cursor: _effectiveMouseCursor(),
        child: child,
      ),
    );
  }

  MouseCursor _effectiveMouseCursor() {
    if (_mouseCursorHidden.value) return SystemMouseCursors.none;
    if (_links.highlighted != null) return SystemMouseCursors.click;
    if (_controller.mouseTracking != .none) return SystemMouseCursors.basic;
    return SystemMouseCursors.text;
  }

  TerminalViewGeometry _geometryFor(BoxConstraints constraints) {
    final width = constraints.hasBoundedWidth ? constraints.maxWidth : 0.0;
    final height = constraints.hasBoundedHeight ? constraints.maxHeight : 0.0;
    final gridWidth = (width - widget.padding.horizontal).clamp(0.0, width);
    final gridHeight = (height - widget.padding.vertical).clamp(0.0, height);
    final (cols, rows) = _metrics.gridSize(gridWidth, gridHeight);
    return TerminalViewGeometry._(
      surfaceBounds: Rect.fromLTWH(0, 0, width, height),
      gridBounds: Rect.fromLTWH(
        widget.padding.left,
        widget.padding.top,
        cols * _metrics.cellWidth,
        rows * _metrics.cellHeight,
      ),
      metrics: _metrics,
      cols: cols,
      rows: rows,
      viewportOffset: _controller.scrollbar.offset,
    );
  }

  void _handleFocusChange(bool focused) {
    _syncBlink(focused: focused);
    if (focused && widget.showKeyboard) {
      _attachment.input.showKeyboard();
      _updateTextInputGeometry();
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    _updateTextInputGeometry();
    final result = _attachment.input.handleKeyEvent(event);

    if (result == .handled || result == .skipRemainingHandlers) {
      _updateTextInputGeometry();
      _syncBlink();
      if (widget.mouseAutoHide == .onInput && !_mouseCursorHidden.value) {
        _mouseCursorHidden.value = true;
      }
    }

    _syncHoveredLink();
    return result;
  }

  void _handleMouseExit(PointerExitEvent event) => _links.cancelHover();

  void _handleMouseHover(PointerHoverEvent event) {
    _links.handleHover(
      localPosition: event.localPosition,
      metrics: _metrics,
      virtualMods: _attachment.virtualMods,
    );
    _mouseCursorHidden.value = false;
  }

  Future<void> _handlePaste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null || data!.text!.isEmpty) return;
    _controller.paste(data.text!);
  }

  void _handleResize(SurfaceMeasurement measurement) {
    _attachment.handleResize(measurement);
    _syncLinkInteraction();
  }

  CellMetrics _measureMetrics({Uint8List? fontData}) {
    return measureCellMetrics(
      fontSize: _theme.fontSize,
      fontWeight: _theme.fontWeight,
      fontFamily: _theme.fontFamily,
      fontFamilyFallback: _theme.fontFamilyFallback,
      fontData: fontData ?? widget.fontData ?? _resolvedFontData,
      devicePixelRatio: _devicePixelRatio,
    );
  }

  void _onControllerChanged() {
    _links.invalidateContent();
    _syncLinkInteraction();
    final activeScreen = _controller.activeScreen;
    if (_scrollController.activeScreen != activeScreen) {
      _scrollController.activeScreen = activeScreen;
    }
    _updateTextInputGeometry();
    _syncBlink();
  }

  void _onScrollChanged() {
    _syncBlink();
    _links.invalidateContent();
    _updateTextInputGeometry();
  }

  /// Asynchronously resolves font data and recomputes metrics when found.
  Future<void> _resolveFontData(String fontFamily) async {
    if (!mounted ||
        widget.fontData != null ||
        _theme.fontFamily != fontFamily) {
      return;
    }
    final data = await FontDataResolver.resolve(fontFamily);
    if (data == null ||
        !mounted ||
        widget.fontData != null ||
        _theme.fontFamily != fontFamily) {
      return;
    }

    _resolvedFontData = data;
    _metrics = _measureMetrics(fontData: data);
    _links.cancel();
    setState(() {});
  }

  void _syncBlink({bool? focused}) {
    _cursorBlink.sync(
      enabled:
          (focused ?? _focusNode.hasFocus) && _attachment.cursorBlinkEnabled,
      interval: _theme.cursor.blinkInterval,
    );
  }

  void _syncHoveredLink() {
    _links.refreshHover(
      metrics: _metrics,
      virtualMods: _attachment.virtualMods,
    );
  }

  void _syncLinkInteraction() {
    final cwd = _controller.pwd;
    final geometry = _attachment.terminal.geometry;
    final context = LinkContext(
      terminal: _attachment.terminal,
      rows: geometry.rows,
      cols: geometry.cols,
      cwd: cwd.isEmpty ? null : cwd,
    );

    _links.update(
      context: context,
      settings: widget.linkSettings,
      idleStyle: _theme.hyperlink.idle,
    );
  }

  void _updateGestureScrollPhysics() {
    final behavior = ScrollConfiguration.of(context);
    final defaultPhysics = behavior.getScrollPhysics(context);
    _gestureScrollPhysics =
        widget.scrollPhysics?.applyTo(defaultPhysics) ?? defaultPhysics;
  }

  void _updateTextInputGeometry() {
    final renderObject = _rendererKey.currentContext?.findRenderObject();
    if (renderObject is! TerminalRenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize) {
      return;
    }

    _attachment.input.updateTextInputGeometry(
      editableSize: renderObject.size,
      transform: renderObject.getTransformTo(null),
      caretRect: renderObject.textInputCaretRect,
      composingRect: renderObject.textInputComposingRect,
    );
  }
}

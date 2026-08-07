@Tags(['ffi'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flterm/src/foundation.dart';
import 'package:flterm/src/rendering.dart';
import 'package:flterm/src/rendering/atlas/atlas_config.dart';
import 'package:flterm/src/rendering/terminal_render_cache.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart';

import 'helpers/font_loader.dart';
import 'helpers/test_selection.dart';

void main() {
  setUpAll(loadBundledFonts);

  const altMetrics = CellMetrics(cellWidth: 10, cellHeight: 20, baseline: 15);
  const defaultCols = 25;
  const defaultMetrics = CellMetrics(
    cellWidth: 8,
    cellHeight: 16,
    baseline: 12,
  );
  const defaultRows = 5;

  TerminalRenderCache createRenderCache() {
    final cache = TerminalRenderCache();
    addTearDown(cache.dispose);
    return cache;
  }

  Widget wrap(
    Terminal terminal, {
    TerminalTheme? theme,
    CellMetrics metrics = defaultMetrics,
    TestSelection? selection,
    double? maxWidth,
    double? maxHeight,
    bool focused = true,
    bool blinkVisible = true,
    OnResize? onResize,
    VoidCallback? onViewportChanged,
    TerminalRenderCache? renderCache,
    ViewportOffset? offset,
  }) {
    selection?.applyTo(terminal);
    renderCache ??= createRenderCache();
    final width = maxWidth ?? defaultCols * metrics.cellWidth;
    final height = maxHeight ?? defaultRows * metrics.cellHeight;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width, maxHeight: height),
          child: TerminalRenderer(
            terminal: terminal,
            theme: theme ?? TerminalTheme.dark(),
            metrics: metrics,
            offset: offset ?? ViewportOffset.zero(),
            renderCache: renderCache,
            renderObserver: _TestRenderObserver(hasFocus: focused),
            blinkVisible: blinkVisible,
            onResize: onResize,
            onViewportChanged: onViewportChanged,
          ),
        ),
      ),
    );
  }

  group('TerminalRenderBox layout', () {
    late Terminal terminal;

    setUp(() => terminal = Terminal(cols: defaultCols, rows: defaultRows));

    tearDown(() => terminal.dispose());

    testWidgets('fills bounded width while grid uses whole cells', (
      tester,
    ) async {
      int? reportedCols;
      await tester.pumpWidget(
        wrap(
          terminal,
          maxWidth: 163.7,
          maxHeight: defaultRows * defaultMetrics.cellHeight,
          onResize: (cols, _) => reportedCols = cols,
        ),
      );
      final box = tester.renderObject<TerminalRenderBox>(
        find.byType(TerminalRenderer),
      );
      expect(box.size.width, 163.7);
      expect(reportedCols, 20);
    });

    testWidgets('fills bounded height while grid uses whole cells', (
      tester,
    ) async {
      int? reportedRows;
      await tester.pumpWidget(
        wrap(
          terminal,
          maxWidth: defaultCols * defaultMetrics.cellWidth,
          maxHeight: 85.3,
          onResize: (_, rows) => reportedRows = rows,
        ),
      );
      final box = tester.renderObject<TerminalRenderBox>(
        find.byType(TerminalRenderer),
      );
      expect(box.size.height, 85.3);
      expect(reportedRows, 5);
    });

    testWidgets('viewport pixels change without redundant grid resize', (
      tester,
    ) async {
      final reported = <(int, int)>[];
      void recordResize(int cols, int rows) => reported.add((cols, rows));

      await tester.pumpWidget(
        wrap(terminal, maxWidth: 163.7, onResize: recordResize),
      );
      await tester.pumpWidget(
        wrap(terminal, maxWidth: 167.9, onResize: recordResize),
      );

      final box = tester.renderObject<TerminalRenderBox>(
        find.byType(TerminalRenderer),
      );
      expect(box.size.width, 167.9);
      expect(reported, [(20, defaultRows)]);
    });

    testWidgets('metrics change triggers layout', (tester) async {
      await tester.pumpWidget(wrap(terminal));
      final box = tester.renderObject<TerminalRenderBox>(
        find.byType(TerminalRenderer),
      );
      final sizeBefore = box.size;

      await tester.pumpWidget(wrap(terminal, metrics: altMetrics));
      expect(box.size, isNot(equals(sizeBefore)));
    });

    testWidgets('onResize fires when grid dimensions change', (tester) async {
      int? reportedCols;
      int? reportedRows;
      await tester.pumpWidget(
        wrap(
          terminal,
          onResize: (cols, rows) {
            reportedCols = cols;
            reportedRows = rows;
          },
        ),
      );
      expect(reportedCols, defaultCols);
      expect(reportedRows, defaultRows);
    });

    testWidgets('theme change triggers layout', (tester) async {
      final renderCache = _TrackingRenderCache();
      addTearDown(renderCache.dispose);
      await tester.pumpWidget(wrap(terminal, renderCache: renderCache));
      final box = tester.renderObject<TerminalRenderBox>(
        find.byType(TerminalRenderer),
      );
      expect(box.theme, TerminalTheme.dark());
      final acquisitionsBefore = renderCache.acquiredKeys.length;

      final light = TerminalTheme.light();
      await tester.pumpWidget(
        wrap(terminal, theme: light, renderCache: renderCache),
      );
      expect(box.theme, light);
      expect(renderCache.acquiredKeys, hasLength(acquisitionsBefore));
    });

    testWidgets('font theme change reacquires atlas', (tester) async {
      final renderCache = _TrackingRenderCache();
      addTearDown(renderCache.dispose);
      await tester.pumpWidget(wrap(terminal, renderCache: renderCache));
      final keyBefore = renderCache.acquiredKeys.last;

      final larger = TerminalTheme.dark().copyWith(fontSize: 18);
      await tester.pumpWidget(
        wrap(terminal, theme: larger, renderCache: renderCache),
      );
      await tester.pump();

      expect(renderCache.acquiredKeys.last, isNot(keyBefore));
    });

    testWidgets('selection change does not trigger layout', (tester) async {
      await tester.pumpWidget(wrap(terminal));
      final box = tester.renderObject<TerminalRenderBox>(
        find.byType(TerminalRenderer),
      );
      final sizeBefore = box.size;

      await tester.pumpWidget(
        wrap(
          terminal,
          selection: const TestSelection(
            start: Position(row: 0, col: 0),
            end: Position(row: 0, col: 4),
          ),
        ),
      );
      expect(box.size, equals(sizeBefore));
    });
  });

  group('TerminalRenderBox blink visibility', () {
    late Terminal terminal;

    setUp(() {
      terminal = Terminal(cols: defaultCols, rows: defaultRows);
      terminal.write(Uint8List.fromList(utf8.encode('hello')));
    });

    tearDown(() => terminal.dispose());

    testWidgets('blinkVisible toggles cursor visibility', (tester) async {
      await tester.pumpWidget(wrap(terminal));
      final box = tester.renderObject<TerminalRenderBox>(
        find.byType(TerminalRenderer),
      );

      expect(box.blinkVisible, isTrue);

      await tester.pumpWidget(wrap(terminal, blinkVisible: false));
      expect(box.blinkVisible, isFalse);

      await tester.pumpWidget(wrap(terminal));
      expect(box.blinkVisible, isTrue);
    });

    testWidgets('unfocused terminal stays mounted', (tester) async {
      await tester.pumpWidget(wrap(terminal, focused: false));
      expect(find.byType(TerminalRenderer), findsOneWidget);
    });
  });

  group('TerminalRenderBox viewport', () {
    testWidgets('notifies after scrolling to another row', (tester) async {
      final terminal = Terminal(cols: defaultCols, rows: defaultRows);
      final offset = _TestViewportOffset();
      addTearDown(terminal.dispose);
      addTearDown(offset.dispose);
      terminal.write(
        Uint8List.fromList(
          List.filled(20, 'scrollback row\r\n').join().codeUnits,
        ),
      );
      var notifications = 0;
      await tester.pumpWidget(
        wrap(
          terminal,
          offset: offset,
          onViewportChanged: () => notifications++,
        ),
      );
      notifications = 0;

      offset.jumpTo(0);
      await tester.pump();

      expect(notifications, 1);
    });
  });
}

class _TrackingRenderCache extends TerminalRenderCache {
  final acquiredKeys = <AtlasConfig>[];

  @override
  TerminalAtlasHandle acquireAtlas(AtlasConfig config) {
    acquiredKeys.add(config);
    return super.acquireAtlas(config);
  }
}

class _TestRenderObserver implements TerminalRenderObserver {
  @override
  final bool hasFocus;

  const _TestRenderObserver({this.hasFocus = true});

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

class _TestViewportOffset extends ViewportOffset {
  double _pixels = 0;

  @override
  bool get allowImplicitScrolling => false;

  @override
  bool get hasPixels => true;

  @override
  double get pixels => _pixels;

  @override
  ScrollDirection get userScrollDirection => .idle;

  @override
  Future<void> animateTo(
    double to, {
    required Duration duration,
    required Curve curve,
  }) async {
    jumpTo(to);
  }

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    return true;
  }

  @override
  bool applyViewportDimension(double viewportDimension) => true;

  @override
  void correctBy(double correction) => _pixels += correction;

  @override
  void jumpTo(double pixels) {
    _pixels = pixels;
    notifyListeners();
  }
}

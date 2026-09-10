@Tags(['ffi'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flterm/src/foundation.dart';
import 'package:flterm/src/rendering.dart';
import 'package:flterm/src/rendering/atlas/atlas_config.dart';
import 'package:flterm/src/rendering/atlas_pool.dart';
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

  AtlasPool createAtlasPool() {
    final pool = AtlasPool();
    addTearDown(pool.dispose);
    return pool;
  }

  Widget wrap(
    Terminal terminal, {
    TerminalTheme? theme,
    CellMetrics metrics = defaultMetrics,
    EdgeInsets surfacePadding = EdgeInsets.zero,
    TestSelection? selection,
    double? maxWidth,
    double? maxHeight,
    bool focused = true,
    bool blinkVisible = true,
    double devicePixelRatio = 1,
    ValueChanged<SurfaceMeasurement>? onGeometryChanged,
    ValueChanged<int>? onViewportRowChanged,
    AtlasPool? atlasPool,
    ViewportOffset? offset,
    bool resizeDeferred = false,
  }) {
    selection?.applyTo(terminal);
    atlasPool ??= createAtlasPool();
    final frameChanges = ChangeNotifier();
    void onTerminalChanged() => frameChanges.notifyListeners();
    terminal.addListener(onTerminalChanged);
    addTearDown(() {
      terminal.removeListener(onTerminalChanged);
      frameChanges.dispose();
    });
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
            frameChanges: frameChanges,
            theme: theme ?? TerminalTheme.dark(),
            metrics: metrics,
            surfacePadding: surfacePadding,
            offset: offset ?? ViewportOffset.zero(),
            atlasPool: atlasPool,
            devicePixelRatio: devicePixelRatio,
            focused: focused,
            blinkVisible: blinkVisible,
            resizeDeferred: resizeDeferred,
            onGeometryChanged: (measurement) {
              final current = terminal.geometry;
              final accepted = SurfaceGeometry.tryFrom(
                resizeDeferred
                    ? SurfaceMeasurement(
                        cols: current.cols,
                        rows: current.rows,
                        cellWidth: measurement.cellWidth,
                        cellHeight: measurement.cellHeight,
                        paddingLeft: measurement.paddingLeft,
                        paddingRight: measurement.paddingRight,
                        paddingTop: measurement.paddingTop,
                        paddingBottom: measurement.paddingBottom,
                        devicePixelRatio: measurement.devicePixelRatio,
                      )
                    : measurement,
              );
              if (accepted == null) return null;
              if (!resizeDeferred) {
                terminal.resize(
                  cols: accepted.cols,
                  rows: accepted.rows,
                  cellWidthPx: accepted.cellWidthPx,
                  cellHeightPx: accepted.cellHeightPx,
                );
              }
              onGeometryChanged?.call(measurement);
              return accepted;
            },
            onViewportRowChanged: onViewportRowChanged ?? (_) {},
          ),
        ),
      ),
    );
  }

  group('TerminalRenderBox layout', () {
    late Terminal terminal;

    setUp(() => terminal = Terminal(cols: defaultCols, rows: defaultRows));

    tearDown(() => terminal.dispose());

    testWidgets('snaps width to whole-cell multiples', (tester) async {
      await tester.pumpWidget(
        wrap(
          terminal,
          maxWidth: 163.7,
          maxHeight: defaultRows * defaultMetrics.cellHeight,
        ),
      );
      final box = tester.renderObject<TerminalRenderBox>(
        find.byType(TerminalRenderer),
      );
      expect(box.size.width, 160.0);
    });

    testWidgets('snaps height to whole-cell multiples', (tester) async {
      await tester.pumpWidget(
        wrap(
          terminal,
          maxWidth: defaultCols * defaultMetrics.cellWidth,
          maxHeight: 85.3,
        ),
      );
      final box = tester.renderObject<TerminalRenderBox>(
        find.byType(TerminalRenderer),
      );
      expect(box.size.height, 80.0);
    });

    testWidgets('uses the terminal grid while resize is deferred', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          terminal,
          maxWidth: 10 * defaultMetrics.cellWidth,
          maxHeight: 3 * defaultMetrics.cellHeight,
          resizeDeferred: true,
        ),
      );

      final box = tester.renderObject<TerminalRenderBox>(
        find.byType(TerminalRenderer),
      );

      expect(box.debugGridSize, (cols: defaultCols, rows: defaultRows));
    });

    testWidgets('reports measured grid while resize is deferred', (
      tester,
    ) async {
      SurfaceMeasurement? reportedGeometry;

      await tester.pumpWidget(
        wrap(
          terminal,
          maxWidth: 10 * defaultMetrics.cellWidth,
          maxHeight: 3 * defaultMetrics.cellHeight,
          resizeDeferred: true,
          onGeometryChanged: (geometry) => reportedGeometry = geometry,
        ),
      );

      expect((reportedGeometry!.cols, reportedGeometry!.rows), (10, 3));
    });

    testWidgets('commits the measured grid when resize deferral ends', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          terminal,
          maxWidth: 10 * defaultMetrics.cellWidth,
          maxHeight: 3 * defaultMetrics.cellHeight,
          resizeDeferred: true,
        ),
      );

      await tester.pumpWidget(
        wrap(
          terminal,
          maxWidth: 10 * defaultMetrics.cellWidth,
          maxHeight: 3 * defaultMetrics.cellHeight,
        ),
      );

      final box = tester.renderObject<TerminalRenderBox>(
        find.byType(TerminalRenderer),
      );
      expect(box.debugGridSize, (cols: 10, rows: 3));
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

    testWidgets('geometry callback reports the complete measured surface', (
      tester,
    ) async {
      SurfaceMeasurement? reportedGeometry;
      await tester.pumpWidget(
        wrap(
          terminal,
          surfacePadding: const EdgeInsets.fromLTRB(8, 6, 4, 2),
          devicePixelRatio: 2,
          onGeometryChanged: (geometry) => reportedGeometry = geometry,
        ),
      );

      expect(reportedGeometry, isNotNull);
      expect(reportedGeometry!.cols, defaultCols);
      expect(reportedGeometry!.rows, defaultRows);
      expect(reportedGeometry!.paddingLeft, 8);
      expect(reportedGeometry!.paddingBottom, 2);
      expect(reportedGeometry!.devicePixelRatio, 2);
    });

    testWidgets('geometry callback fires when physical cell geometry changes', (
      tester,
    ) async {
      var resizeCount = 0;
      await tester.pumpWidget(
        wrap(
          terminal,
          onGeometryChanged: (_) => resizeCount++,
          maxWidth: defaultCols * altMetrics.cellWidth,
          maxHeight: defaultRows * altMetrics.cellHeight,
        ),
      );
      await tester.pumpWidget(
        wrap(
          terminal,
          metrics: altMetrics,
          onGeometryChanged: (_) => resizeCount++,
          maxWidth: defaultCols * altMetrics.cellWidth,
          maxHeight: defaultRows * altMetrics.cellHeight,
        ),
      );

      expect(resizeCount, 2);
    });

    testWidgets('geometry callback fires when surface padding changes', (
      tester,
    ) async {
      var resizeCount = 0;
      await tester.pumpWidget(
        wrap(terminal, onGeometryChanged: (_) => resizeCount++),
      );
      await tester.pumpWidget(
        wrap(
          terminal,
          surfacePadding: const EdgeInsets.fromLTRB(8, 6, 4, 2),
          onGeometryChanged: (_) => resizeCount++,
        ),
      );

      expect(resizeCount, 2);
    });

    testWidgets('clears layout state when the geometry callback throws', (
      tester,
    ) async {
      final error = StateError('geometry failed');

      await tester.pumpWidget(
        wrap(terminal, onGeometryChanged: (_) => throw error),
      );
      expect(tester.takeException(), same(error));

      await tester.pumpWidget(wrap(terminal));

      expect(
        tester
            .renderObject<TerminalRenderBox>(find.byType(TerminalRenderer))
            .size,
        const Size(200, 80),
      );
    });

    testWidgets('geometry callback initializes a replacement terminal', (
      tester,
    ) async {
      final replacement = Terminal(cols: defaultCols, rows: defaultRows);
      addTearDown(replacement.dispose);

      await tester.pumpWidget(wrap(terminal));
      await tester.pumpWidget(wrap(replacement));

      expect(
        replacement.geometry,
        const TerminalGeometry(
          cols: defaultCols,
          rows: defaultRows,
          widthPx: defaultCols * 8,
          heightPx: defaultRows * 16,
        ),
      );
    });

    testWidgets('theme change triggers layout', (tester) async {
      final atlasPool = _TrackingAtlasPool();
      addTearDown(atlasPool.dispose);
      await tester.pumpWidget(wrap(terminal, atlasPool: atlasPool));
      final box = tester.renderObject<TerminalRenderBox>(
        find.byType(TerminalRenderer),
      );
      expect(box.theme, TerminalTheme.dark());
      final acquisitionsBefore = atlasPool.acquiredKeys.length;

      final light = TerminalTheme.light();
      await tester.pumpWidget(
        wrap(terminal, theme: light, atlasPool: atlasPool),
      );
      expect(box.theme, light);
      expect(atlasPool.acquiredKeys, hasLength(acquisitionsBefore));
    });

    testWidgets('font theme change reacquires atlas', (tester) async {
      final atlasPool = _TrackingAtlasPool();
      addTearDown(atlasPool.dispose);
      await tester.pumpWidget(wrap(terminal, atlasPool: atlasPool));
      final keyBefore = atlasPool.acquiredKeys.last;

      final larger = TerminalTheme.dark().copyWith(fontSize: 18);
      await tester.pumpWidget(
        wrap(terminal, theme: larger, atlasPool: atlasPool),
      );
      await tester.pump();

      expect(atlasPool.acquiredKeys.last, isNot(keyBefore));
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
      final requestedRows = <int>[];
      await tester.pumpWidget(
        wrap(terminal, offset: offset, onViewportRowChanged: requestedRows.add),
      );
      requestedRows.clear();

      offset.jumpTo(0);
      await tester.pump();

      expect(requestedRows, [0]);
    });
  });
}

class _TrackingAtlasPool extends AtlasPool {
  final acquiredKeys = <AtlasConfig>[];

  @override
  AtlasLease acquireAtlas(AtlasConfig config) {
    acquiredKeys.add(config);
    return super.acquireAtlas(config);
  }
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

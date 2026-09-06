@Tags(['ffi'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flterm/flterm.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TerminalViewGeometry', () {
    testWidgets('uses the full view coordinate space including padding', (
      tester,
    ) async {
      final controller = TerminalController();
      addTearDown(controller.dispose);
      late TerminalViewGeometry geometry;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 200,
              height: 100,
              child: TerminalView(
                controller: controller,
                padding: const EdgeInsets.all(10),
                overlayBuilder: (context, value) {
                  geometry = value;
                  return const SizedBox.expand();
                },
              ),
            ),
          ),
        ),
      );

      final firstCell = geometry.cellRect(const Position(row: 0, col: 0));

      expect(geometry.surfaceBounds, const Rect.fromLTWH(0, 0, 200, 100));
      expect(geometry.gridBounds.topLeft, const Offset(10, 10));
      expect(firstCell, isNotNull);
      expect(firstCell!.topLeft, const Offset(10, 10));
      expect(geometry.cellAt(firstCell.center), const Position(row: 0, col: 0));
      expect(geometry.cellAt(Offset.zero), isNull);
    });

    testWidgets('converts a visible search selection to pixel rectangles', (
      tester,
    ) async {
      final controller = TerminalController();
      addTearDown(controller.dispose);
      late TerminalViewGeometry geometry;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 300,
            height: 100,
            child: TerminalView(
              controller: controller,
              padding: const EdgeInsets.all(10),
              overlayBuilder: (context, value) {
                geometry = value;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      );
      controller.write(Uint8List.fromList(utf8.encode('hello world')));
      controller.search.search('hello');
      controller.search.next();
      await tester.pump();

      final selection = controller.search.selectedMatch!;
      final rects = geometry.selectionRects(selection);
      final startRect = geometry.gridRefRect(selection.start);

      expect(rects, hasLength(1));
      expect(startRect, isNotNull);
      expect(rects.single.topLeft, startRect!.topLeft);
      expect(rects.single.width, startRect.width * 5);
    });

    testWidgets('rebuilds after viewport changes without a search', (
      tester,
    ) async {
      final controller = TerminalController(
        config: const TerminalConfig(cols: 20, rows: 3),
      );
      addTearDown(controller.dispose);
      var builds = 0;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 300,
            height: 100,
            child: TerminalView(
              controller: controller,
              overlayBuilder: (context, geometry) {
                builds++;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      );
      controller.write(
        Uint8List.fromList(utf8.encode(List.filled(100, 'line\r\n').join())),
      );
      await tester.pumpAndSettle();
      controller.scrollToBottom();
      await tester.pump();
      final buildsBeforeScroll = builds;

      controller.scrollToTop();
      await tester.pump();

      expect(builds, buildsBeforeScroll + 1);
    });
  });
}

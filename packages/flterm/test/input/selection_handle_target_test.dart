import 'package:flterm/src/input/selection_handle_geometry.dart'
    show SelectionHandleLayout;
import 'package:flterm/src/input/selection_handle_target.dart'
    show SelectionHandleTarget;
import 'package:flterm/src/input/selection_session.dart' show SelectionEndpoint;
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart' show Position;
import 'package:material_ui/material_ui.dart';

void main() {
  group('SelectionHandleTarget', () {
    const start = SelectionHandleLayout(
      anchor: Offset(16, 24),
      endpoint: SelectionEndpoint.start,
      leading: true,
      position: Position(row: 0, col: 1),
      type: TextSelectionHandleType.left,
    );
    const end = SelectionHandleLayout(
      anchor: Offset(24, 24),
      endpoint: SelectionEndpoint.end,
      leading: false,
      position: Position(row: 0, col: 2),
      type: TextSelectionHandleType.right,
    );

    SelectionHandleTarget target(
      SelectionHandleLayout layout, {
      required Offset? peerAnchor,
      GestureDragStartCallback? onDragStart,
    }) => SelectionHandleTarget(
      layout: layout,
      lineHeight: 16,
      controls: materialTextSelectionHandleControls,
      peerAnchor: peerAnchor,
      onDragStart: onDragStart ?? (_) {},
      onDragUpdate: (_) {},
      onDragEnd: (_) {},
      onDragCancel: () {},
    );

    Future<void> pump(WidgetTester tester, List<Widget> handles) =>
        tester.pumpWidget(
          MaterialApp(
            home: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 64,
                height: 48,
                child: Stack(children: handles),
              ),
            ),
          ),
        );

    testWidgets('provides a minimum 48-pixel touch target', (tester) async {
      await pump(tester, [target(start, peerAnchor: null)]);

      final size = tester.getSize(
        find.byKey(const ValueKey(SelectionEndpoint.start)),
      );

      expect(size, const Size.square(48));
    });

    testWidgets('routes overlapping targets to the nearest endpoint', (
      tester,
    ) async {
      SelectionEndpoint? dragged;
      await pump(tester, [
        target(
          start,
          peerAnchor: end.anchor,
          onDragStart: (_) => dragged = .start,
        ),
        target(
          end,
          peerAnchor: start.anchor,
          onDragStart: (_) => dragged = .end,
        ),
      ]);

      final gesture = await tester.startGesture(start.anchor);
      await gesture.moveBy(const Offset(-20, 0));
      await gesture.up();

      expect(dragged, SelectionEndpoint.start);
    });
  });
}

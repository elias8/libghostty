@Tags(['golden'])
library;

import 'package:flterm/src/input/selection_cupertino_handle_controls.dart'
    show selectionCupertinoHandleControls;
import 'package:flterm/src/input/selection_handle_geometry.dart'
    show SelectionHandleLayout;
import 'package:flterm/src/input/selection_handle_target.dart'
    show SelectionHandleTarget;
import 'package:flterm/src/input/selection_session.dart' show SelectionEndpoint;
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart' show Position;
import 'package:material_ui/material_ui.dart';

import '../rendering/helpers/font_loader.dart' show loadBundledFonts;

void main() {
  group('TerminalSelectionHandles golden', () {
    const start = SelectionHandleLayout(
      anchor: Offset(16, 80),
      leading: true,
      endpoint: SelectionEndpoint.start,
      position: Position(row: 4, col: 2),
      type: TextSelectionHandleType.left,
    );
    const end = SelectionHandleLayout(
      anchor: Offset(80, 80),
      leading: false,
      endpoint: SelectionEndpoint.end,
      position: Position(row: 4, col: 9),
      type: TextSelectionHandleType.right,
    );
    final sceneKey = GlobalKey();

    Future<void> pumpSubject(
      WidgetTester tester,
      TargetPlatform platform,
    ) async {
      await loadBundledFonts();
      final controls = platform == TargetPlatform.android
          ? materialTextSelectionHandleControls
          : selectionCupertinoHandleControls;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(128, 128);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        RepaintBoundary(
          key: sceneKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(platform: platform),
            home: ColoredBox(
              color: const Color(0xFFF3F3F3),
              child: Center(
                child: SizedBox(
                  width: 96,
                  height: 80,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Positioned.fill(
                        child: ColoredBox(color: Color(0xFF102A43)),
                      ),
                      const Positioned(
                        left: 16,
                        top: 64,
                        width: 64,
                        height: 16,
                        child: ColoredBox(
                          color: Color(0xFF214E68),
                          child: Center(
                            child: Text(
                              'SELECTED',
                              style: TextStyle(
                                color: Color(0xFFFFE082),
                                fontFamily: 'JetBrains Mono',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                height: 1,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SelectionHandleTarget(
                        layout: start,
                        controls: controls,
                        lineHeight: 16,
                        peerAnchor: end.anchor,
                        onDragStart: (_) {},
                        onDragUpdate: (_) {},
                        onDragEnd: (_) {},
                        onDragCancel: () {},
                      ),
                      SelectionHandleTarget(
                        layout: end,
                        controls: controls,
                        lineHeight: 16,
                        peerAnchor: start.anchor,
                        onDragStart: (_) {},
                        onDragUpdate: (_) {},
                        onDragEnd: (_) {},
                        onDragCancel: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    group('platform handles', () {
      testWidgets('matches Android Material endpoints', (tester) async {
        await pumpSubject(tester, TargetPlatform.android);

        await expectLater(
          find.byKey(sceneKey),
          matchesGoldenFile('goldens/selection_handles_android.png'),
        );
      });

      testWidgets('matches iOS Cupertino endpoints', (tester) async {
        await pumpSubject(tester, TargetPlatform.iOS);

        await expectLater(
          find.byKey(sceneKey),
          matchesGoldenFile('goldens/selection_handles_ios.png'),
        );
      });
    });
  });
}

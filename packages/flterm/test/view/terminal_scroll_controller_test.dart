import 'package:flterm/src/view/terminal_scroll_controller.dart';
import 'package:flutter/rendering.dart' show ScrollDirection, ViewportOffset;
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart' show TerminalScreen;
import 'package:material_ui/material_ui.dart';

void main() {
  Widget buildScrollable(
    TerminalScrollController controller, {
    double contentHeight = 500,
    double viewportHeight = 200,
    ScrollPhysics? physics,
  }) {
    return MaterialApp(
      home: SizedBox(
        height: viewportHeight,
        child: ListView(
          controller: controller,
          physics: physics,
          children: [SizedBox(height: contentHeight)],
        ),
      ),
    );
  }

  group('TerminalScrollController', () {
    late TerminalScrollController controller;

    setUp(() => controller = TerminalScrollController());

    tearDown(() => controller.dispose());

    group('constructor', () {
      test('defaults activeScreen to primary', () {
        expect(controller.activeScreen, TerminalScreen.primary);
      });
    });

    group('createScrollPosition', () {
      testWidgets('creates a single-context scroll position', (tester) async {
        await tester.pumpWidget(buildScrollable(controller));

        expect(controller.position, isA<ScrollPositionWithSingleContext>());
      });
    });

    group('activeScreen', () {
      testWidgets('propagates to attached positions', (tester) async {
        await tester.pumpWidget(buildScrollable(controller));

        setTerminalScrollControllerActiveScreen(controller, .alternate);

        expect(controller.activeScreen, TerminalScreen.alternate);

        setTerminalScrollControllerActiveScreen(controller, .primary);
        expect(controller.activeScreen, TerminalScreen.primary);
      });
    });
  });

  group('scroll position', () {
    late TerminalScrollController controller;

    setUp(() => controller = TerminalScrollController());

    tearDown(() => controller.dispose());

    group('content dimensions', () {
      testWidgets('uses finite extents in primary mode', (tester) async {
        await tester.pumpWidget(buildScrollable(controller));

        final position = controller.position;
        expect(position.maxScrollExtent.isFinite, isTrue);
      });

      testWidgets('uses infinite extents in alternate mode', (tester) async {
        await tester.pumpWidget(buildScrollable(controller));

        setTerminalScrollControllerActiveScreen(controller, .alternate);
        await tester.pumpWidget(
          buildScrollable(controller, contentHeight: 501),
        );

        final position = controller.position;
        expect(position.maxScrollExtent, double.infinity);
        expect(position.minScrollExtent, double.negativeInfinity);
      });
    });

    group('activeScreen', () {
      testWidgets('saves and restores pixels on mode switch', (tester) async {
        await tester.pumpWidget(buildScrollable(controller));

        controller.jumpTo(100);
        await tester.pump();
        expect(controller.position.pixels, 100);

        setTerminalScrollControllerActiveScreen(controller, .alternate);
        await tester.pumpWidget(buildScrollable(controller));

        controller.jumpTo(9999);
        await tester.pump();
        expect(controller.position.pixels, 9999);

        setTerminalScrollControllerActiveScreen(controller, .primary);
        await tester.pumpWidget(buildScrollable(controller));

        expect(controller.position.pixels, 100);
      });

      testWidgets('clamps restored pixels to new extents', (tester) async {
        await tester.pumpWidget(buildScrollable(controller));

        final maxExtent = controller.position.maxScrollExtent;
        controller.jumpTo(maxExtent);
        await tester.pump();

        setTerminalScrollControllerActiveScreen(controller, .alternate);
        await tester.pumpWidget(buildScrollable(controller));

        await tester.pumpWidget(
          buildScrollable(controller, contentHeight: 200),
        );

        setTerminalScrollControllerActiveScreen(controller, .primary);
        await tester.pumpWidget(
          buildScrollable(controller, contentHeight: 200),
        );

        expect(controller.position.pixels, 0);
      });

      testWidgets('restores pixels after scroll physics replaces position', (
        tester,
      ) async {
        await tester.pumpWidget(buildScrollable(controller));
        controller.jumpTo(100);
        await tester.pump();

        setTerminalScrollControllerActiveScreen(controller, .alternate);
        await tester.pumpWidget(
          buildScrollable(
            controller,
            physics: const NeverScrollableScrollPhysics(),
          ),
        );
        setTerminalScrollControllerActiveScreen(controller, .primary);
        await tester.pumpWidget(buildScrollable(controller));

        expect(controller.position.pixels, 100);
      });

      test('restores the logical row after cell height changes', () {
        final source = _TestViewportOffset();
        final viewport = TerminalViewportCoordinator.bind(source, (_) {});
        addTearDown(source.dispose);
        addTearDown(viewport.releaseBinding);
        viewport.submitLayout(
          screen: .primary,
          viewportRow: 20,
          scrollbackRows: 20,
          cellHeight: 20,
          viewportDimension: 200,
        );
        source.jumpTo(100);

        viewport.submitLayout(
          screen: .alternate,
          viewportRow: 0,
          scrollbackRows: 0,
          cellHeight: 20,
          viewportDimension: 200,
        );
        viewport.submitLayout(
          screen: .primary,
          viewportRow: 5,
          scrollbackRows: 20,
          cellHeight: 40,
          viewportDimension: 200,
        );

        expect(source.pixels, 200);
      });
    });

    group('listeners', () {
      testWidgets('notifies on scroll in alternate mode', (tester) async {
        await tester.pumpWidget(buildScrollable(controller));

        setTerminalScrollControllerActiveScreen(controller, .alternate);
        await tester.pumpWidget(buildScrollable(controller));

        var notified = false;
        controller.addListener(() => notified = true);

        controller.jumpTo(50);

        expect(notified, isTrue);
      });
    });
  });
}

final class _TestViewportOffset extends ViewportOffset {
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

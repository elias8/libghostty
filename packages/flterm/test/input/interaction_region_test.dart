@Tags(['ffi'])
library;

import 'dart:convert';

import 'package:flterm/src/controller/terminal_controller.dart'
    show TerminalController, ViewAttachment;
import 'package:flterm/src/foundation.dart';
import 'package:flterm/src/input/interaction_region.dart';
import 'package:flterm/src/input/selection_session.dart' show SelectionEndpoint;
import 'package:flterm/src/links/link_interaction.dart';
import 'package:flterm/src/links/link_settings.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart'
    show
        Mods,
        MouseTracking,
        Position,
        Selection,
        SelectionGestureBehaviors,
        Terminal;

extension _SelectionEdges on Selection {
  Position get _startPoint => start.positionIn(.viewport)!;

  Position get _endPoint => end.positionIn(.viewport)!;

  bool get _forward {
    final start = _startPoint;
    final end = _endPoint;
    return start.row != end.row ? start.row < end.row : start.col <= end.col;
  }

  int get startRow => _startPoint.row;

  int get startCol => _forward ? _startPoint.col : _startPoint.col + 1;

  int get endRow => _endPoint.row;

  int get endCol => _forward ? _endPoint.col + 1 : _endPoint.col;

  TerminalSelectionShape get mode {
    return rectangle
        ? TerminalSelectionShape.rectangle
        : TerminalSelectionShape.normal;
  }
}

void main() {
  group('InteractionRegion', () {
    const defaultMetrics = CellMetrics(
      cellWidth: 8,
      cellHeight: 16,
      baseline: 12,
    );
    final enableNormalMouse = Uint8List.fromList(utf8.encode('\x1b[?1000h'));
    final enableX10Mouse = Uint8List.fromList(utf8.encode('\x1b[?9h'));
    final enableSgrMouse = Uint8List.fromList(
      utf8.encode('\x1b[?1000h\x1b[?1006h'),
    );
    final enableButtonSgrMouse = Uint8List.fromList(
      utf8.encode('\x1b[?1002h\x1b[?1006h'),
    );
    final enableAnySgrMouse = Uint8List.fromList(
      utf8.encode('\x1b[?1003h\x1b[?1006h'),
    );

    final adapters = <TerminalController, ViewAttachment>{};

    ViewAttachment bindingFor(TerminalController controller) {
      return adapters.putIfAbsent(controller, () {
        final adapter = ViewAttachment(controller);
        addTearDown(adapter.dispose);
        return adapter;
      });
    }

    Terminal terminalFor(TerminalController controller) {
      return bindingFor(controller).terminal;
    }

    void writeToTerminal(TerminalController controller, String text) {
      terminalFor(controller).write(Uint8List.fromList(utf8.encode(text)));
    }

    void commitGeometry(
      TerminalController controller, {
      int cols = 80,
      int rows = 24,
      CellMetrics metrics = defaultMetrics,
    }) {
      bindingFor(controller).commitGeometry(
        SurfaceMeasurement(
          cols: cols,
          rows: rows,
          cellWidth: metrics.cellWidth,
          cellHeight: metrics.cellHeight,
          paddingLeft: 0,
          paddingRight: 0,
          paddingTop: 0,
          paddingBottom: 0,
          devicePixelRatio: 1,
        ),
      );
    }

    Widget buildHandler({
      required TerminalController controller,
      ViewAttachment? attachment,
      CellMetrics metrics = defaultMetrics,
      TerminalGestureSettings gestureSettings = const TerminalGestureSettings(),
      LinkInteraction? links,
      ValueChanged<ActivatedLink>? onLinkActivate,
      ScrollPhysics scrollPhysics = const ClampingScrollPhysics(),
    }) {
      final resolvedAttachment = attachment ?? bindingFor(controller);
      commitGeometry(
        controller,
        cols: controller.config.cols,
        rows: controller.config.rows,
        metrics: metrics,
      );
      final resolvedLinks = links ?? LinkInteraction();
      if (links == null) addTearDown(resolvedLinks.dispose);
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: InteractionRegion(
            readVirtualMods: resolvedAttachment.readVirtualMods,
            onMouseInput: resolvedAttachment.onMouseInput,
            onScrollInput: resolvedAttachment.onScrollInput,
            selection: resolvedAttachment.selectionInput,
            metrics: metrics,
            terminalBackground: TerminalTheme.dark().background,
            interaction: resolvedAttachment.interaction,
            onViewportRowChanged: resolvedAttachment.handleViewportRowChanged,
            links: resolvedLinks,
            onLinkActivate: onLinkActivate,
            settings: gestureSettings,
            scrollPhysics: scrollPhysics,
            child: const SizedBox(width: 640, height: 384),
          ),
        ),
      );
    }

    LinkInteraction linkInteractionFor(TerminalController controller) {
      final links = LinkInteraction();
      addTearDown(links.dispose);
      links.update(
        context: LinkContext(
          terminal: terminalFor(controller),
          rows: 24,
          cols: 80,
          cwd: null,
        ),
        settings: LinkSettings(modifier: .none, onActivate: (_) {}),
        idleStyle: const HyperlinkStyle(),
      );
      return links;
    }

    void enableMouseTracking(
      TerminalController controller, {
      MouseTracking mode = .normal,
    }) {
      final seq = switch (mode) {
        .normal => enableNormalMouse,
        .x10 => enableX10Mouse,
        _ => enableNormalMouse,
      };
      final viewBinding = bindingFor(controller);
      viewBinding.terminal.write(seq);
      commitGeometry(controller);
    }

    void enableSgrMouseTracking(TerminalController controller) {
      final viewBinding = bindingFor(controller);
      viewBinding.terminal.write(enableSgrMouse);
      commitGeometry(controller);
    }

    void enableAnySgrMouseTracking(TerminalController controller) {
      final viewBinding = bindingFor(controller);
      viewBinding.terminal.write(enableAnySgrMouse);
      commitGeometry(controller);
    }

    void enableButtonSgrMouseTracking(TerminalController controller) {
      final viewBinding = bindingFor(controller);
      viewBinding.terminal.write(enableButtonSgrMouse);
      commitGeometry(controller);
    }

    String decodeEvents(List<Uint8List> events) {
      return utf8.decode(
        Uint8List.fromList(events.expand((event) => event).toList()),
      );
    }

    List<int> sgrCodes(List<Uint8List> events) {
      return RegExp('\x1b\\[<(\\d+);').allMatches(decodeEvents(events)).map((
        match,
      ) {
        return int.parse(match.group(1)!);
      }).toList();
    }

    List<({int x, int y})> sgrPositions(List<Uint8List> events) {
      return RegExp(
        '\x1b\\[<\\d+;(\\d+);(\\d+)[Mm]',
      ).allMatches(decodeEvents(events)).map((match) {
        return (x: int.parse(match.group(1)!), y: int.parse(match.group(2)!));
      }).toList();
    }

    Future<void> sendPointerEvent(
      WidgetTester tester,
      PointerEvent event,
    ) async {
      await tester.sendEventToBinding(event);
      await tester.pump();
    }

    Future<TestGesture> mouseDown(
      WidgetTester tester,
      Offset pos, {
      int buttons = kPrimaryButton,
      int? pointer,
    }) {
      return tester.startGesture(
        pos,
        kind: .mouse,
        buttons: buttons,
        pointer: pointer,
      );
    }

    late TerminalController controller;

    setUp(() {
      adapters.clear();
      controller = TerminalController();
    });

    tearDown(() {
      controller.dispose();
      adapters.clear();
    });

    Future<void> tapMouse(
      WidgetTester tester,
      Offset position, {
      int count = 1,
    }) async {
      for (var i = 0; i < count; i++) {
        final gesture = await mouseDown(tester, position);
        await gesture.up();
      }
    }

    group('selection ownership', () {
      testWidgets('tap leaves selection empty', (tester) async {
        await tester.pumpWidget(buildHandler(controller: controller));

        await tapMouse(tester, const Offset(40, 16));

        expect(terminalFor(controller).selection, isNull);
      });

      testWidgets('tap activates a link without starting selection', (
        tester,
      ) async {
        final links = <ActivatedLink>[];
        writeToTerminal(controller, 'https://example.test');
        final linkInteraction = linkInteractionFor(controller);

        await tester.pumpWidget(
          buildHandler(
            controller: controller,
            links: linkInteraction,
            onLinkActivate: links.add,
          ),
        );

        await tapMouse(tester, const Offset(8, 0));

        expect(links, hasLength(1));
        expect(links.single.text, 'https://example.test');
        expect(terminalFor(controller).selection, isNull);
      });

      testWidgets('tap up activates the press candidate after invalidation', (
        tester,
      ) async {
        final links = <ActivatedLink>[];
        writeToTerminal(controller, 'https://example.test');
        final linkInteraction = linkInteractionFor(controller);

        await tester.pumpWidget(
          buildHandler(
            controller: controller,
            links: linkInteraction,
            onLinkActivate: links.add,
          ),
        );

        final gesture = await mouseDown(tester, const Offset(8, 0));
        linkInteraction.invalidateContent();
        await gesture.up();

        expect(links.single.text, 'https://example.test');
      });

      testWidgets('replacing link interaction cancels the outgoing press', (
        tester,
      ) async {
        writeToTerminal(controller, 'https://example.test');
        final outgoing = linkInteractionFor(controller);
        final incoming = linkInteractionFor(controller);

        await tester.pumpWidget(
          buildHandler(controller: controller, links: outgoing),
        );
        final gesture = await mouseDown(tester, const Offset(8, 0));
        await tester.pumpWidget(
          buildHandler(controller: controller, links: incoming),
        );

        final staleLink = outgoing.handleRelease(
          localPosition: const Offset(8, 0),
          metrics: defaultMetrics,
        );
        await gesture.up();

        expect(staleLink, isNull);
      });

      testWidgets('drag cancels claimed link tap', (tester) async {
        final links = <ActivatedLink>[];
        writeToTerminal(controller, 'https://example.test');
        final linkInteraction = linkInteractionFor(controller);

        await tester.pumpWidget(
          buildHandler(
            controller: controller,
            links: linkInteraction,
            onLinkActivate: links.add,
          ),
        );

        final gesture = await mouseDown(tester, const Offset(8, 0));
        await tester.pump(kPressTimeout);
        await gesture.moveTo(const Offset(80, 32));
        await gesture.up();

        expect(links, isEmpty);
      });

      testWidgets('touch scroll cancels a claimed link tap', (tester) async {
        writeToTerminal(controller, '\x1b[?1049hhttps://example.test');
        final linkInteraction = linkInteractionFor(controller);

        await tester.pumpWidget(
          buildHandler(controller: controller, links: linkInteraction),
        );
        final gesture = await tester.startGesture(const Offset(8, 8));
        await tester.pump(kPressTimeout);
        await gesture.moveBy(const Offset(0, 64));
        await gesture.up();
        final released = linkInteraction.handleRelease(
          localPosition: const Offset(8, 8),
          metrics: defaultMetrics,
        );

        expect(released, isNull);
      });

      testWidgets('mouse tracking takes priority over link activation', (
        tester,
      ) async {
        final links = <ActivatedLink>[];
        writeToTerminal(controller, 'https://example.test');
        final linkInteraction = linkInteractionFor(controller);
        enableMouseTracking(controller);

        await tester.pumpWidget(
          buildHandler(
            controller: controller,
            links: linkInteraction,
            onLinkActivate: links.add,
          ),
        );

        await tapMouse(tester, const Offset(8, 0));

        expect(links, isEmpty);
      });

      testWidgets('drag creates selection with correct cells', (tester) async {
        await tester.pumpWidget(buildHandler(controller: controller));

        final gesture = await mouseDown(tester, const Offset(8, 0));
        await gesture.moveTo(const Offset(40, 16));
        await gesture.up();

        final selection = terminalFor(controller).selection!;
        expect(selection.startRow, 0);
        expect(selection.startCol, 1);
        expect(selection.endRow, 1);
        expect(selection.endCol, 5);
        expect(selection.mode, TerminalSelectionShape.normal);
      });

      testWidgets('stylus drag creates selection', (tester) async {
        await tester.pumpWidget(buildHandler(controller: controller));

        final gesture = await tester.startGesture(
          const Offset(8, 0),
          kind: .stylus,
          pointer: 83,
        );
        await gesture.moveTo(const Offset(40, 16));
        await gesture.up();

        expect(terminalFor(controller).selection, isNotNull);
      });

      testWidgets('inverted stylus drag creates selection', (tester) async {
        await tester.pumpWidget(buildHandler(controller: controller));

        final gesture = await tester.startGesture(
          const Offset(8, 0),
          kind: .invertedStylus,
          pointer: 84,
        );
        await gesture.moveTo(const Offset(40, 16));
        await gesture.up();

        expect(terminalFor(controller).selection, isNotNull);
      });

      testWidgets('mouse up ends selection drag', (tester) async {
        await tester.pumpWidget(buildHandler(controller: controller));

        final gesture = await mouseDown(tester, Offset.zero);
        await gesture.moveTo(const Offset(80, 32));
        await gesture.up();

        final selection = terminalFor(controller).selection!;
        expect(selection.startRow, 0);
        expect(selection.endRow, 2);
      });

      testWidgets('drag to same cell does not change selection', (
        tester,
      ) async {
        await tester.pumpWidget(buildHandler(controller: controller));

        final gesture = await mouseDown(tester, const Offset(8, 0));
        await gesture.moveTo(const Offset(40, 16));
        final selAfterFirst = terminalFor(controller).selection;

        await gesture.moveTo(const Offset(41, 17));
        final selAfterSecond = terminalFor(controller).selection;

        expect(selAfterFirst, selAfterSecond);

        await gesture.up();
      });

      testWidgets('selection autoscroll follows the committed grid', (
        tester,
      ) async {
        final target = TerminalController(
          config: const TerminalConfig(cols: 10, rows: 2),
        );
        addTearDown(target.dispose);
        final attachment = bindingFor(target);
        final scrollController = ScrollController();
        addTearDown(scrollController.dispose);
        commitGeometry(target, cols: 10, rows: 2);
        writeToTerminal(
          target,
          '0\r\n1\r\n2\r\n3\r\n4\r\n5\r\n6\r\n7\r\n8\r\n9',
        );
        target.scrollToTop();
        await tester.pumpWidget(
          Directionality(
            textDirection: .ltr,
            child: Scrollable(
              controller: scrollController,
              viewportBuilder: (_, _) =>
                  buildHandler(controller: target, attachment: attachment),
            ),
          ),
        );
        final pointer = await mouseDown(tester, const Offset(8, 8));

        await pointer.moveTo(const Offset(8, 64));
        await tester.pump();
        final rowAfterMove = target.scrollbar.offset;
        await tester.pump(const Duration(milliseconds: 120));
        final viewportRow = target.scrollbar.offset;
        await pointer.up();
        await tester.pump(const Duration(milliseconds: 250));

        expect(viewportRow, greaterThan(rowAfterMove));
      });

      testWidgets('double click selects word', (tester) async {
        writeToTerminal(controller, 'hello world');

        await tester.pumpWidget(buildHandler(controller: controller));

        await tapMouse(tester, const Offset(8, 0), count: 2);

        final selection = terminalFor(controller).selection!;
        expect(selection.startRow, 0);
        expect(selection.startCol, 0);
        expect(selection.endCol, 5);
      });

      testWidgets('distant pointer timestamps do not form a double click', (
        tester,
      ) async {
        writeToTerminal(controller, 'hello world');
        await tester.pumpWidget(buildHandler(controller: controller));

        const position = Offset(8, 0);
        final firstPointer = TestPointer(81, PointerDeviceKind.mouse);
        await sendPointerEvent(tester, firstPointer.down(position));
        await sendPointerEvent(
          tester,
          firstPointer.up(timeStamp: const Duration(milliseconds: 10)),
        );
        final secondPointer = TestPointer(82, PointerDeviceKind.mouse);
        await sendPointerEvent(
          tester,
          secondPointer.down(position, timeStamp: const Duration(seconds: 1)),
        );
        await sendPointerEvent(
          tester,
          secondPointer.up(timeStamp: const Duration(milliseconds: 1010)),
        );

        expect(terminalFor(controller).selection, isNull);
      });

      testWidgets('double click on second word selects it', (tester) async {
        writeToTerminal(controller, 'hello world');

        await tester.pumpWidget(buildHandler(controller: controller));

        await tapMouse(tester, const Offset(56, 0), count: 2);

        final selection = terminalFor(controller).selection!;
        expect(selection.startCol, 6);
        expect(selection.endCol, 11);
      });

      testWidgets('double click uses configured word boundaries', (
        tester,
      ) async {
        final boundaryController = TerminalController();
        addTearDown(boundaryController.dispose);
        writeToTerminal(boundaryController, 'hello_world');

        await tester.pumpWidget(
          buildHandler(
            controller: boundaryController,
            gestureSettings: const TerminalGestureSettings(wordBoundaries: '_'),
          ),
        );

        await tapMouse(tester, const Offset(64, 0), count: 2);

        final selection = terminalFor(boundaryController).selection!;
        expect(selection.startCol, 6);
        expect(selection.endCol, 11);
      });

      testWidgets('triple click selects line content only', (tester) async {
        writeToTerminal(controller, 'Hello');

        await tester.pumpWidget(buildHandler(controller: controller));

        await tapMouse(tester, const Offset(40, 0), count: 3);

        final selection = terminalFor(controller).selection!;
        expect(selection.startCol, 0);
        expect(selection.endCol, 5);
      });

      testWidgets('triple click on wrapped line selects full terminal line', (
        tester,
      ) async {
        final narrowController = TerminalController(
          config: const TerminalConfig(cols: 10, rows: 5),
        );
        addTearDown(narrowController.dispose);

        writeToTerminal(narrowController, 'ABCDEFGHIJKLMNO');

        await tester.pumpWidget(buildHandler(controller: narrowController));

        await tapMouse(tester, const Offset(8, 16), count: 3);

        final selection = terminalFor(narrowController).selection!;
        expect(selection.startRow, 0);
        expect(selection.startCol, 0);
        expect(selection.endRow, 1);
        expect(selection.endCol, 5);
      });

      testWidgets('triple click with fullRow mode selects entire row width', (
        tester,
      ) async {
        final wideController = TerminalController(
          config: const TerminalConfig(cols: 20, rows: 5),
        );
        addTearDown(wideController.dispose);

        writeToTerminal(wideController, 'Hello');

        await tester.pumpWidget(
          buildHandler(
            controller: wideController,
            gestureSettings: const TerminalGestureSettings(
              lineSelectMode: .full,
            ),
          ),
        );

        await tapMouse(tester, const Offset(8, 0), count: 3);

        final selection = terminalFor(wideController).selection!;
        expect(selection.endCol, 20);
      });

      testWidgets('tap counting resets on distant clicks', (tester) async {
        await tester.pumpWidget(buildHandler(controller: controller));

        await tapMouse(tester, const Offset(40, 16));
        await tapMouse(tester, const Offset(200, 200));

        expect(terminalFor(controller).selection, isNull);
      });

      testWidgets('touch long press starts normal selection by default', (
        tester,
      ) async {
        await tester.pumpWidget(buildHandler(controller: controller));

        final gesture = await tester.startGesture(const Offset(40, 16));

        await tester.pump(const Duration(milliseconds: 550));

        expect(terminalFor(controller).selection, isNull);

        await gesture.moveTo(const Offset(80, 32));
        final sel = terminalFor(controller).selection!;
        expect(sel.mode, TerminalSelectionShape.normal);

        await gesture.up();
      });

      testWidgets(
        'controller notification preserves touch handles before movement',
        (tester) async {
          debugDefaultTargetPlatformOverride = TargetPlatform.android;
          addTearDown(() => debugDefaultTargetPlatformOverride = null);
          await tester.pumpWidget(buildHandler(controller: controller));
          final gesture = await tester.startGesture(const Offset(40, 16));
          await tester.pump(const Duration(milliseconds: 550));

          controller.toggleMod(const Mods.ctrl());
          await tester.pump();
          await gesture.moveTo(const Offset(80, 32));
          await gesture.up();
          await tester.pump();
          debugDefaultTargetPlatformOverride = null;

          expect(
            find.byKey(const ValueKey(SelectionEndpoint.start)),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'touch move cancels long press if distance exceeds threshold',
        (tester) async {
          await tester.pumpWidget(buildHandler(controller: controller));

          final gesture = await tester.startGesture(const Offset(40, 16));
          await gesture.moveTo(const Offset(80, 16));

          await tester.pump(const Duration(milliseconds: 550));

          await gesture.moveTo(const Offset(120, 16));
          expect(terminalFor(controller).selection, isNull);

          await gesture.up();
        },
      );

      testWidgets('new click clears existing selection', (tester) async {
        await tester.pumpWidget(buildHandler(controller: controller));

        final gesture = await mouseDown(tester, Offset.zero);
        await gesture.moveTo(const Offset(80, 32));
        await gesture.up();

        expect(terminalFor(controller).selection, isNotNull);

        final gesture2 = await mouseDown(tester, const Offset(40, 16));
        await gesture2.up();

        expect(terminalFor(controller).selection, isNull);
      });

      testWidgets('click without existing selection keeps selection null', (
        tester,
      ) async {
        await tester.pumpWidget(buildHandler(controller: controller));

        final gesture = await mouseDown(tester, const Offset(40, 16));
        await gesture.up();

        expect(terminalFor(controller).selection, isNull);
      });
    });

    group('gesture settings', () {
      Future<TestGesture> startBlockLongPressHandleDrag(
        WidgetTester tester,
      ) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        await tester.pumpWidget(
          buildHandler(
            controller: controller,
            gestureSettings: const TerminalGestureSettings(
              longPressSelectionShape: .rectangle,
            ),
          ),
        );
        final selection = await tester.startGesture(const Offset(40, 16));
        await tester.pump(const Duration(milliseconds: 550));
        await selection.moveTo(const Offset(80, 32));
        await selection.up();
        await tester.pump();
        final handle = find.byKey(const ValueKey(SelectionEndpoint.end));
        debugDefaultTargetPlatformOverride = null;
        final drag = await tester.startGesture(tester.getCenter(handle));
        return drag;
      }

      testWidgets('dragSelection false prevents drag selection', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildHandler(
            controller: controller,
            gestureSettings: const TerminalGestureSettings(
              dragSelection: false,
            ),
          ),
        );

        final gesture = await mouseDown(tester, const Offset(8, 0));
        await gesture.moveTo(const Offset(80, 32));
        await gesture.up();

        expect(terminalFor(controller).selection, isNull);
      });

      testWidgets('longPressSelection false cancels press selection', (
        tester,
      ) async {
        writeToTerminal(controller, 'hello world');

        await tester.pumpWidget(
          buildHandler(
            controller: controller,
            gestureSettings: const TerminalGestureSettings(
              longPressSelection: false,
              selectionBehaviors: SelectionGestureBehaviors(
                singleClick: .line,
                doubleClick: .word,
                tripleClick: .line,
              ),
            ),
          ),
        );

        final gesture = await tester.startGesture(const Offset(40, 16));
        await tester.pump(const Duration(milliseconds: 550));
        await gesture.moveTo(const Offset(80, 32));
        await gesture.up();

        expect(terminalFor(controller).selection, isNull);
      });

      testWidgets('single click uses configured line behavior', (tester) async {
        writeToTerminal(controller, 'hello world');

        await tester.pumpWidget(
          buildHandler(
            controller: controller,
            gestureSettings: const TerminalGestureSettings(
              selectionBehaviors: SelectionGestureBehaviors(
                singleClick: .line,
                doubleClick: .word,
                tripleClick: .line,
              ),
            ),
          ),
        );

        await tapMouse(tester, const Offset(8, 0));

        final selection = terminalFor(controller).selection!;
        expect(selection.startCol, 0);
        expect(selection.endCol, 11);
      });

      testWidgets('double click uses configured line behavior', (tester) async {
        writeToTerminal(controller, 'hello world');

        await tester.pumpWidget(
          buildHandler(
            controller: controller,
            gestureSettings: const TerminalGestureSettings(
              selectionBehaviors: SelectionGestureBehaviors(
                singleClick: .cell,
                doubleClick: .line,
                tripleClick: .line,
              ),
            ),
          ),
        );

        await tapMouse(tester, const Offset(8, 0), count: 2);

        final selection = terminalFor(controller).selection!;
        expect(selection.startCol, 0);
        expect(selection.endCol, 11);
      });

      testWidgets('triple click uses configured word behavior', (tester) async {
        writeToTerminal(controller, 'hello world');

        await tester.pumpWidget(
          buildHandler(
            controller: controller,
            gestureSettings: const TerminalGestureSettings(
              selectionBehaviors: SelectionGestureBehaviors(
                singleClick: .cell,
                doubleClick: .line,
                tripleClick: .word,
              ),
            ),
          ),
        );

        await tapMouse(tester, const Offset(56, 0), count: 3);

        final selection = terminalFor(controller).selection!;
        expect(selection.startCol, 6);
        expect(selection.endCol, 11);
      });

      testWidgets('dragSelection false keeps press selection enabled', (
        tester,
      ) async {
        writeToTerminal(controller, 'hello world');

        await tester.pumpWidget(
          buildHandler(
            controller: controller,
            gestureSettings: const TerminalGestureSettings(
              dragSelection: false,
            ),
          ),
        );

        final gesture = await mouseDown(tester, const Offset(8, 0));
        await gesture.moveTo(const Offset(80, 32));
        await gesture.up();
        expect(terminalFor(controller).selection, isNull);

        await tapMouse(tester, const Offset(8, 0), count: 2);

        final selection = terminalFor(controller).selection!;
        expect(selection.startCol, 0);
        expect(selection.endCol, 5);
      });

      testWidgets('double click cell behavior leaves selection empty', (
        tester,
      ) async {
        writeToTerminal(controller, 'hello world');

        await tester.pumpWidget(
          buildHandler(
            controller: controller,
            gestureSettings: const TerminalGestureSettings(
              selectionBehaviors: SelectionGestureBehaviors(
                singleClick: .cell,
                doubleClick: .cell,
                tripleClick: .line,
              ),
            ),
          ),
        );

        await tapMouse(tester, const Offset(8, 0), count: 2);

        expect(terminalFor(controller).selection, isNull);
      });

      testWidgets('triple click cell behavior leaves selection empty', (
        tester,
      ) async {
        writeToTerminal(controller, 'hello world');

        await tester.pumpWidget(
          buildHandler(
            controller: controller,
            gestureSettings: const TerminalGestureSettings(
              selectionBehaviors: SelectionGestureBehaviors(
                singleClick: .cell,
                doubleClick: .word,
                tripleClick: .cell,
              ),
            ),
          ),
        );

        await tapMouse(tester, const Offset(8, 0), count: 3);

        expect(terminalFor(controller).selection, isNull);
      });

      testWidgets('block long press follows inactive modifier during drag', (
        tester,
      ) async {
        final drag = await startBlockLongPressHandleDrag(tester);
        await drag.moveBy(const Offset(8, 0));
        await drag.up();

        final selection = terminalFor(controller).selection!;
        expect(selection.mode, TerminalSelectionShape.normal);
      });

      testWidgets('modifier release changes a block long press to normal', (
        tester,
      ) async {
        controller.toggleMod(const Mods.alt());
        final drag = await startBlockLongPressHandleDrag(tester);

        controller.toggleMod(const Mods.alt());
        await drag.moveBy(const Offset(8, 0));
        await drag.up();

        expect(
          terminalFor(controller).selection!.mode,
          TerminalSelectionShape.normal,
        );
      });

      testWidgets(
        'disabled selection affordances still allow mouse tracking output',
        (tester) async {
          enableMouseTracking(controller);

          await tester.pumpWidget(
            buildHandler(
              controller: controller,
              gestureSettings: const TerminalGestureSettings(
                dragSelection: false,
                longPressSelection: false,
                selectAllShortcut: false,
              ),
            ),
          );

          final events = <Uint8List>[];
          controller.onOutput = events.add;

          final gesture = await mouseDown(tester, const Offset(24, 16));
          await gesture.up();

          expect(events, isNotEmpty);
        },
      );
    });

    group('physical mods', () {
      testWidgets('Alt press changes an active selection to rectangular', (
        tester,
      ) async {
        await tester.pumpWidget(buildHandler(controller: controller));
        final gesture = await mouseDown(tester, const Offset(8, 0));
        addTearDown(gesture.up);
        await gesture.moveTo(const Offset(80, 32));

        await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
        addTearDown(HardwareKeyboard.instance.clearState);

        expect(
          terminalFor(controller).selection!.mode,
          TerminalSelectionShape.rectangle,
        );
      });

      testWidgets('Alt release changes an active selection to normal', (
        tester,
      ) async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
        addTearDown(HardwareKeyboard.instance.clearState);
        await tester.pumpWidget(buildHandler(controller: controller));
        final gesture = await mouseDown(tester, const Offset(8, 0));
        addTearDown(gesture.up);
        await gesture.moveTo(const Offset(80, 32));

        await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);

        expect(
          terminalFor(controller).selection!.mode,
          TerminalSelectionShape.normal,
        );
      });
    });

    group('virtual mods', () {
      testWidgets('virtual alt triggers block selection on drag', (
        tester,
      ) async {
        controller.toggleMod(const Mods.alt());

        await tester.pumpWidget(buildHandler(controller: controller));

        final gesture = await mouseDown(tester, const Offset(8, 0));
        await gesture.moveTo(const Offset(80, 32));
        await gesture.up();

        final selection = terminalFor(controller).selection!;
        expect(selection.mode, TerminalSelectionShape.rectangle);
      });

      testWidgets('virtual alt triggers block selection on long press', (
        tester,
      ) async {
        controller.toggleMod(const Mods.alt());

        await tester.pumpWidget(buildHandler(controller: controller));

        final gesture = await tester.startGesture(const Offset(40, 16));
        await tester.pump(const Duration(milliseconds: 550));
        await gesture.moveTo(const Offset(80, 32));
        await gesture.up();

        final selection = terminalFor(controller).selection!;
        expect(selection.mode, TerminalSelectionShape.rectangle);
      });

      testWidgets('toggling alt mid-drag switches selection mode', (
        tester,
      ) async {
        await tester.pumpWidget(buildHandler(controller: controller));

        final gesture = await mouseDown(tester, const Offset(8, 0));
        await gesture.moveTo(const Offset(80, 32));
        expect(
          terminalFor(controller).selection!.mode,
          TerminalSelectionShape.normal,
        );

        controller.toggleMod(const Mods.alt());
        await gesture.moveTo(const Offset(80, 48));
        expect(
          terminalFor(controller).selection!.mode,
          TerminalSelectionShape.rectangle,
        );

        controller.toggleMod(const Mods.alt());
        await gesture.moveTo(const Offset(80, 64));
        expect(
          terminalFor(controller).selection!.mode,
          TerminalSelectionShape.normal,
        );

        await gesture.up();
      });

      testWidgets('virtual shift bypasses mouse tracking', (tester) async {
        controller.toggleMod(const Mods.shift());
        enableMouseTracking(controller);

        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));

        final gesture = await mouseDown(tester, const Offset(24, 16));
        await gesture.up();

        expect(events, isEmpty);
      });

      testWidgets('virtual control is encoded in tracked mouse input', (
        tester,
      ) async {
        controller.toggleMod(const Mods.ctrl());
        enableSgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        await sendPointerEvent(
          tester,
          const PointerDownEvent(
            pointer: 500,
            position: Offset(24, 16),
            kind: PointerDeviceKind.mouse,
          ),
        );
        await sendPointerEvent(
          tester,
          const PointerUpEvent(
            pointer: 500,
            position: Offset(24, 16),
            kind: PointerDeviceKind.mouse,
          ),
        );

        expect(sgrCodes(events), [16, 16]);
      });
    });

    group('wide character selection snapping', () {
      setUp(() {
        terminalFor(controller).write(Uint8List.fromList(utf8.encode('AB日CD')));
      });

      testWidgets('drag from spacer snaps anchor inclusive', (tester) async {
        await tester.pumpWidget(buildHandler(controller: controller));

        final gesture = await mouseDown(tester, const Offset(24, 0));
        await gesture.moveTo(const Offset(40, 0));
        await gesture.up();

        expect(controller.selectedText(), '日C');
      });

      testWidgets('drag ending on wide char snaps end exclusive', (
        tester,
      ) async {
        await tester.pumpWidget(buildHandler(controller: controller));

        final gesture = await mouseDown(tester, Offset.zero);
        await gesture.moveTo(const Offset(24, 0));
        expect(controller.selectedText(), 'AB日');

        await gesture.moveTo(const Offset(16, 0));
        expect(controller.selectedText(), 'AB');

        await gesture.up();
      });

      testWidgets('leftward drag from spacer snaps anchor exclusive', (
        tester,
      ) async {
        await tester.pumpWidget(buildHandler(controller: controller));

        final gesture = await mouseDown(tester, const Offset(24, 0));
        await gesture.moveTo(Offset.zero);
        await gesture.up();

        expect(controller.selectedText(), 'AB日');
      });

      testWidgets('narrow cells pass through unaffected', (tester) async {
        await tester.pumpWidget(buildHandler(controller: controller));

        final gesture = await mouseDown(tester, Offset.zero);
        await gesture.moveTo(const Offset(8, 0));
        await gesture.up();

        final selection = terminalFor(controller).selection!;
        expect(selection.startCol, 0);
        expect(selection.endCol, 1);
      });

      testWidgets('double click on spacer leaves selection empty', (
        tester,
      ) async {
        await tester.pumpWidget(buildHandler(controller: controller));

        await tapMouse(tester, const Offset(24, 0), count: 2);

        expect(terminalFor(controller).selection, isNull);
      });
    });

    group('lifecycle', () {
      testWidgets('preserves a settled selection on unmount', (tester) async {
        writeToTerminal(controller, 'selected');
        controller.selectAll();
        await tester.pumpWidget(buildHandler(controller: controller));

        await tester.pumpWidget(const SizedBox());

        expect(controller.hasSelection, isTrue);
      });

      testWidgets('preserves outgoing selection on controller replacement', (
        tester,
      ) async {
        writeToTerminal(controller, 'selected');
        controller.selectAll();
        final replacement = TerminalController();
        addTearDown(replacement.dispose);
        await tester.pumpWidget(buildHandler(controller: controller));

        await tester.pumpWidget(buildHandler(controller: replacement));

        expect(controller.hasSelection, isTrue);
      });

      testWidgets('preserves incoming selection on controller replacement', (
        tester,
      ) async {
        final replacement = TerminalController();
        addTearDown(replacement.dispose);
        writeToTerminal(replacement, 'selected');
        replacement.selectAll();
        await tester.pumpWidget(buildHandler(controller: controller));

        await tester.pumpWidget(buildHandler(controller: replacement));

        expect(replacement.hasSelection, isTrue);
      });

      testWidgets(
        'does not retain the outgoing interaction owner after replacement',
        (tester) async {
          final replacement = TerminalController();
          addTearDown(replacement.dispose);
          writeToTerminal(replacement, 'selected');
          bindingFor(replacement).commitGeometry(
            SurfaceMeasurement(
              cols: 80,
              rows: 24,
              cellWidth: defaultMetrics.cellWidth,
              cellHeight: defaultMetrics.cellHeight,
              paddingLeft: 0,
              paddingRight: 0,
              paddingTop: 0,
              paddingBottom: 0,
              devicePixelRatio: 1,
            ),
          );
          await tester.pumpWidget(buildHandler(controller: controller));

          final outgoing = await mouseDown(
            tester,
            const Offset(8, 8),
            pointer: 24,
          );
          await tester.pumpWidget(buildHandler(controller: replacement));

          final incoming = await mouseDown(
            tester,
            const Offset(8, 8),
            pointer: 25,
          );
          await incoming.moveTo(const Offset(80, 8));
          expect(replacement.hasSelection, isTrue);
          await sendPointerEvent(
            tester,
            const PointerCancelEvent(pointer: 25, position: Offset(80, 8)),
          );

          expect(replacement.hasSelection, isFalse);
          await incoming.removePointer();
          await outgoing.up();
        },
      );

      testWidgets('releases a forwarded mouse press on unmount', (
        tester,
      ) async {
        enableSgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;
        await tester.pumpWidget(buildHandler(controller: controller));
        final gesture = await mouseDown(
          tester,
          const Offset(24, 16),
          pointer: 1001,
        );
        events.clear();

        await tester.pumpWidget(const SizedBox());

        expect(decodeEvents(events), '\x1b[<0;4;2m');
        await gesture.up();
      });

      testWidgets('releases a forwarded press from the outgoing controller', (
        tester,
      ) async {
        enableSgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;
        final replacement = TerminalController();
        addTearDown(replacement.dispose);
        await tester.pumpWidget(buildHandler(controller: controller));
        final gesture = await mouseDown(
          tester,
          const Offset(24, 16),
          pointer: 1002,
        );
        events.clear();

        await tester.pumpWidget(buildHandler(controller: replacement));

        expect(decodeEvents(events), '\x1b[<0;4;2m');
        await gesture.up();
      });
    });

    group('mouse tracking', () {
      testWidgets('maps primary mouse button to left', (tester) async {
        enableSgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        await sendPointerEvent(
          tester,
          const PointerDownEvent(
            pointer: 1,
            position: Offset(24, 16),
            kind: PointerDeviceKind.mouse,
          ),
        );
        await sendPointerEvent(
          tester,
          const PointerUpEvent(
            pointer: 1,
            position: Offset(24, 16),
            kind: PointerDeviceKind.mouse,
          ),
        );

        expect(sgrCodes(events), [0, 0]);
      });

      testWidgets('maps middle mouse button to middle', (tester) async {
        enableSgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        await sendPointerEvent(
          tester,
          const PointerDownEvent(
            pointer: 2,
            position: Offset(24, 16),
            kind: PointerDeviceKind.mouse,
            buttons: kMiddleMouseButton,
          ),
        );
        await sendPointerEvent(
          tester,
          const PointerUpEvent(
            pointer: 2,
            position: Offset(24, 16),
            kind: PointerDeviceKind.mouse,
          ),
        );

        expect(sgrCodes(events), [1, 1]);
      });

      testWidgets('maps secondary mouse button to right', (tester) async {
        enableSgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        await sendPointerEvent(
          tester,
          const PointerDownEvent(
            pointer: 3,
            position: Offset(24, 16),
            kind: PointerDeviceKind.mouse,
            buttons: kSecondaryMouseButton,
          ),
        );
        await sendPointerEvent(
          tester,
          const PointerUpEvent(
            pointer: 3,
            position: Offset(24, 16),
            kind: PointerDeviceKind.mouse,
          ),
        );

        expect(sgrCodes(events), [2, 2]);
      });

      testWidgets('maps back and forward mouse buttons independently', (
        tester,
      ) async {
        enableSgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        await sendPointerEvent(
          tester,
          const PointerDownEvent(
            pointer: 4,
            position: Offset(24, 16),
            kind: PointerDeviceKind.mouse,
            buttons: kBackMouseButton,
          ),
        );
        await sendPointerEvent(
          tester,
          const PointerUpEvent(
            pointer: 4,
            position: Offset(24, 16),
            kind: PointerDeviceKind.mouse,
          ),
        );
        await sendPointerEvent(
          tester,
          const PointerDownEvent(
            pointer: 5,
            position: Offset(24, 16),
            kind: PointerDeviceKind.mouse,
            buttons: kForwardMouseButton,
          ),
        );
        await sendPointerEvent(
          tester,
          const PointerUpEvent(
            pointer: 5,
            position: Offset(24, 16),
            kind: PointerDeviceKind.mouse,
          ),
        );

        expect(sgrCodes(events), [128, 128, 129, 129]);
      });

      testWidgets('retains the pressed button during motion', (tester) async {
        enableAnySgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        await sendPointerEvent(
          tester,
          const PointerDownEvent(
            pointer: 6,
            position: Offset(24, 16),
            kind: PointerDeviceKind.mouse,
            buttons: kSecondaryMouseButton,
          ),
        );
        await sendPointerEvent(
          tester,
          const PointerMoveEvent(
            pointer: 6,
            position: Offset(32, 16),
            kind: PointerDeviceKind.mouse,
            buttons: kSecondaryMouseButton,
          ),
        );
        await sendPointerEvent(
          tester,
          const PointerUpEvent(
            pointer: 6,
            position: Offset(32, 16),
            kind: PointerDeviceKind.mouse,
          ),
        );

        expect(sgrCodes(events), [2, 34, 2]);
      });

      testWidgets('reports mouse button changes within one pointer sequence', (
        tester,
      ) async {
        enableAnySgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        await sendPointerEvent(
          tester,
          const PointerDownEvent(
            pointer: 41,
            position: Offset(24, 16),
            kind: PointerDeviceKind.mouse,
          ),
        );
        await sendPointerEvent(
          tester,
          const PointerMoveEvent(
            pointer: 41,
            position: Offset(24, 16),
            kind: PointerDeviceKind.mouse,
            buttons: kPrimaryMouseButton | kSecondaryMouseButton,
          ),
        );
        await sendPointerEvent(
          tester,
          const PointerMoveEvent(
            pointer: 41,
            position: Offset(24, 16),
            kind: PointerDeviceKind.mouse,
            buttons: kSecondaryMouseButton,
          ),
        );
        await sendPointerEvent(
          tester,
          const PointerMoveEvent(
            pointer: 41,
            position: Offset(32, 16),
            kind: PointerDeviceKind.mouse,
            buttons: kSecondaryMouseButton,
          ),
        );
        await sendPointerEvent(
          tester,
          const PointerUpEvent(
            pointer: 41,
            position: Offset(32, 16),
            kind: PointerDeviceKind.mouse,
          ),
        );

        expect(
          decodeEvents(events),
          '\x1b[<0;4;2M\x1b[<2;4;2M\x1b[<0;4;2m'
          '\x1b[<34;5;2M\x1b[<2;5;2m',
        );
      });

      testWidgets('keeps terminal ownership when tracking changes', (
        tester,
      ) async {
        enableAnySgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        await sendPointerEvent(
          tester,
          const PointerDownEvent(
            pointer: 40,
            position: Offset(24, 16),
            kind: PointerDeviceKind.mouse,
          ),
        );
        writeToTerminal(controller, '\x1b[?1003l');
        await tester.pump();
        await sendPointerEvent(
          tester,
          const PointerMoveEvent(
            pointer: 40,
            position: Offset(32, 16),
            kind: PointerDeviceKind.mouse,
          ),
        );
        writeToTerminal(controller, '\x1b[?1003h\x1b[?1006h');
        await tester.pump();
        await sendPointerEvent(
          tester,
          const PointerMoveEvent(
            pointer: 40,
            position: Offset(40, 16),
            kind: PointerDeviceKind.mouse,
          ),
        );

        await sendPointerEvent(
          tester,
          const PointerUpEvent(
            pointer: 40,
            position: Offset(40, 16),
            kind: PointerDeviceKind.mouse,
          ),
        );

        expect(sgrCodes(events), [0, 32, 0]);
      });

      testWidgets('keeps terminal ownership when Shift changes', (
        tester,
      ) async {
        enableAnySgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;
        await tester.pumpWidget(buildHandler(controller: controller));
        final gesture = await mouseDown(
          tester,
          const Offset(24, 16),
          pointer: 1003,
        );
        events.clear();

        await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
        await gesture.moveBy(const Offset(8, 0));
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
        await gesture.up();

        expect(sgrCodes(events), [36, 0]);
      });

      testWidgets('keeps simultaneous pointers independent', (tester) async {
        enableButtonSgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        await sendPointerEvent(
          tester,
          const PointerDownEvent(
            pointer: 14,
            position: Offset(24, 16),
            kind: PointerDeviceKind.mouse,
          ),
        );
        await sendPointerEvent(
          tester,
          const PointerDownEvent(
            pointer: 15,
            position: Offset(32, 16),
            kind: PointerDeviceKind.mouse,
            buttons: kSecondaryMouseButton,
          ),
        );
        await sendPointerEvent(
          tester,
          const PointerUpEvent(
            pointer: 14,
            position: Offset(24, 16),
            kind: PointerDeviceKind.mouse,
          ),
        );
        await sendPointerEvent(
          tester,
          const PointerMoveEvent(
            pointer: 15,
            position: Offset(40, 16),
            kind: PointerDeviceKind.mouse,
            buttons: kSecondaryMouseButton,
          ),
        );
        await sendPointerEvent(
          tester,
          const PointerUpEvent(
            pointer: 15,
            position: Offset(40, 16),
            kind: PointerDeviceKind.mouse,
          ),
        );

        expect(sgrCodes(events), [0, 2, 0, 34, 2]);
      });

      testWidgets('forwards aggregate buttons and ignores unknown buttons', (
        tester,
      ) async {
        enableSgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        await sendPointerEvent(
          tester,
          const PointerDownEvent(
            pointer: 7,
            position: Offset(24, 16),
            kind: PointerDeviceKind.mouse,
            buttons: kPrimaryMouseButton | kSecondaryMouseButton,
          ),
        );
        await sendPointerEvent(
          tester,
          const PointerUpEvent(
            pointer: 7,
            position: Offset(24, 16),
            kind: PointerDeviceKind.mouse,
          ),
        );
        await sendPointerEvent(
          tester,
          const PointerDownEvent(
            pointer: 8,
            position: Offset(24, 16),
            kind: PointerDeviceKind.mouse,
            buttons: 0x20,
          ),
        );
        await sendPointerEvent(
          tester,
          const PointerDownEvent(
            pointer: 19,
            position: Offset(24, 16),
            kind: PointerDeviceKind.unknown,
          ),
        );

        expect(sgrCodes(events), [0, 2, 0, 2]);
      });

      testWidgets('forwards stylus contact and barrel buttons', (tester) async {
        enableSgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        await sendPointerEvent(
          tester,
          const PointerDownEvent(
            pointer: 9,
            position: Offset(24, 16),
            kind: PointerDeviceKind.stylus,
          ),
        );
        await sendPointerEvent(
          tester,
          const PointerUpEvent(
            pointer: 9,
            position: Offset(24, 16),
            kind: PointerDeviceKind.stylus,
          ),
        );
        await sendPointerEvent(
          tester,
          const PointerDownEvent(
            pointer: 10,
            position: Offset(24, 16),
            kind: PointerDeviceKind.invertedStylus,
            buttons: kStylusContact | kPrimaryStylusButton,
          ),
        );
        await sendPointerEvent(
          tester,
          const PointerUpEvent(
            pointer: 10,
            position: Offset(24, 16),
            kind: PointerDeviceKind.invertedStylus,
          ),
        );

        expect(sgrCodes(events), [0, 0, 2, 2]);
      });

      testWidgets('maps a secondary stylus barrel button to middle', (
        tester,
      ) async {
        enableSgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        await sendPointerEvent(
          tester,
          const PointerDownEvent(
            pointer: 18,
            position: Offset(24, 16),
            kind: PointerDeviceKind.stylus,
            buttons: kSecondaryStylusButton,
          ),
        );
        await sendPointerEvent(
          tester,
          const PointerUpEvent(
            pointer: 18,
            position: Offset(24, 16),
            kind: PointerDeviceKind.stylus,
          ),
        );

        expect(sgrCodes(events), [1, 1]);
      });

      testWidgets('reports stylus barrel changes within one pointer sequence', (
        tester,
      ) async {
        enableAnySgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        await sendPointerEvent(
          tester,
          const PointerDownEvent(
            pointer: 42,
            position: Offset(24, 16),
            kind: PointerDeviceKind.stylus,
          ),
        );
        await sendPointerEvent(
          tester,
          const PointerMoveEvent(
            pointer: 42,
            position: Offset(24, 16),
            kind: PointerDeviceKind.stylus,
            buttons: kStylusContact | kPrimaryStylusButton,
          ),
        );
        await sendPointerEvent(
          tester,
          const PointerMoveEvent(
            pointer: 42,
            position: Offset(32, 16),
            kind: PointerDeviceKind.stylus,
            buttons: kStylusContact | kPrimaryStylusButton,
          ),
        );
        await sendPointerEvent(
          tester,
          const PointerMoveEvent(
            pointer: 42,
            position: Offset(32, 16),
            kind: PointerDeviceKind.stylus,
          ),
        );
        await sendPointerEvent(
          tester,
          const PointerUpEvent(
            pointer: 42,
            position: Offset(32, 16),
            kind: PointerDeviceKind.stylus,
          ),
        );

        expect(
          decodeEvents(events),
          '\x1b[<0;4;2M\x1b[<0;4;2m\x1b[<2;4;2M'
          '\x1b[<34;5;2M\x1b[<2;5;2m\x1b[<0;5;2M\x1b[<0;5;2m',
        );
      });

      testWidgets('cancelling a tracked pointer emits one release', (
        tester,
      ) async {
        enableSgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        await sendPointerEvent(
          tester,
          const PointerDownEvent(
            pointer: 11,
            position: Offset(24, 16),
            kind: PointerDeviceKind.mouse,
          ),
        );
        await sendPointerEvent(
          tester,
          const PointerCancelEvent(
            pointer: 11,
            position: Offset(24, 16),
            kind: PointerDeviceKind.mouse,
          ),
        );
        await sendPointerEvent(
          tester,
          const PointerCancelEvent(
            pointer: 11,
            position: Offset(24, 16),
            kind: PointerDeviceKind.mouse,
          ),
        );

        expect(sgrCodes(events), [0, 0]);
      });

      testWidgets('ignores cancellation without a forwarded press', (
        tester,
      ) async {
        enableSgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        await sendPointerEvent(
          tester,
          const PointerCancelEvent(
            pointer: 20,
            position: Offset(24, 16),
            kind: PointerDeviceKind.mouse,
          ),
        );

        expect(events, isEmpty);
      });

      testWidgets(
        'does not cancel an active selection for an unrelated pointer',
        (tester) async {
          await tester.pumpWidget(buildHandler(controller: controller));
          final mouse = await mouseDown(
            tester,
            const Offset(8, 8),
            pointer: 22,
          );
          await mouse.moveTo(const Offset(80, 8));
          expect(controller.hasSelection, isTrue);

          await sendPointerEvent(
            tester,
            const PointerDownEvent(pointer: 23, position: Offset(8, 8)),
          );
          await sendPointerEvent(
            tester,
            const PointerCancelEvent(pointer: 23, position: Offset(8, 8)),
          );

          expect(controller.hasSelection, isTrue);
          await mouse.up();
        },
      );

      testWidgets('does not synthesize a click when touch is cancelled', (
        tester,
      ) async {
        enableSgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        await sendPointerEvent(
          tester,
          const PointerDownEvent(pointer: 21, position: Offset(24, 16)),
        );
        await sendPointerEvent(
          tester,
          const PointerCancelEvent(pointer: 21, position: Offset(24, 16)),
        );

        expect(events, isEmpty);
      });

      testWidgets('forwards only the first simultaneous touch contact', (
        tester,
      ) async {
        enableSgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        await sendPointerEvent(
          tester,
          const PointerDownEvent(pointer: 31, position: Offset(24, 16)),
        );
        await sendPointerEvent(
          tester,
          const PointerDownEvent(pointer: 32, position: Offset(32, 16)),
        );
        await sendPointerEvent(
          tester,
          const PointerUpEvent(pointer: 32, position: Offset(32, 16)),
        );
        await sendPointerEvent(
          tester,
          const PointerUpEvent(pointer: 31, position: Offset(24, 16)),
        );

        expect(decodeEvents(events), '\x1b[<0;4;2M\x1b[<0;4;2m');
      });

      testWidgets('forwards hover only in any-event tracking', (tester) async {
        enableAnySgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        await sendPointerEvent(
          tester,
          const PointerHoverEvent(
            pointer: 12,
            position: Offset(24, 16),
            kind: PointerDeviceKind.mouse,
          ),
        );

        expect(sgrCodes(events), [35]);
      });

      testWidgets('rejects hover in button-event tracking', (tester) async {
        enableSgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        await sendPointerEvent(
          tester,
          const PointerHoverEvent(
            pointer: 16,
            position: Offset(24, 16),
            kind: PointerDeviceKind.mouse,
          ),
        );

        expect(events, isEmpty);
      });

      testWidgets('encodes vertical and horizontal wheel directions', (
        tester,
      ) async {
        enableSgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        await sendPointerEvent(
          tester,
          const PointerScrollEvent(
            position: Offset(24, 16),
            scrollDelta: Offset(8, -16),
          ),
        );

        expect(sgrCodes(events), [64, 67]);
      });

      testWidgets('accepts horizontal wheel input as the first sequence', (
        tester,
      ) async {
        enableSgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        await sendPointerEvent(
          tester,
          const PointerScrollEvent(
            position: Offset(24, 16),
            scrollDelta: Offset(8, 0),
          ),
        );

        expect(sgrCodes(events), [67]);
      });

      testWidgets('clears selection when tracked wheel scrolling starts', (
        tester,
      ) async {
        writeToTerminal(controller, 'hello world');
        controller.selectAll();
        enableSgrMouseTracking(controller);
        final selectionAtOutput = <bool>[];
        controller.onOutput = (_) {
          selectionAtOutput.add(controller.hasSelection);
        };

        await tester.pumpWidget(buildHandler(controller: controller));
        await sendPointerEvent(
          tester,
          const PointerScrollEvent(
            position: Offset(24, 16),
            scrollDelta: Offset(0, -16),
          ),
        );

        expect(controller.hasSelection, isFalse);
        expect(selectionAtOutput, isNotEmpty);
        expect(selectionAtOutput, everyElement(isFalse));
      });

      testWidgets('tracked scroll cancels selection auto-scroll', (
        tester,
      ) async {
        writeToTerminal(controller, 'hello world');
        enableSgrMouseTracking(controller);
        final scrollController = ScrollController();
        addTearDown(scrollController.dispose);
        commitGeometry(controller, rows: 2);

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Scrollable(
              controller: scrollController,
              viewportBuilder: (_, _) => buildHandler(controller: controller),
            ),
          ),
        );
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
        final selection = await mouseDown(tester, const Offset(8, 8));
        await selection.moveTo(const Offset(8, 64));
        await tester.pump();
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);

        final trackpad = TestPointer(1062, PointerDeviceKind.trackpad);
        const position = Offset(24, 16);
        await sendPointerEvent(tester, trackpad.panZoomStart(position));
        await sendPointerEvent(
          tester,
          trackpad.panZoomUpdate(position, pan: const Offset(0, 16)),
        );
        await sendPointerEvent(tester, trackpad.panZoomEnd());
        expect(controller.hasSelection, isFalse);
        await tester.pump(const Duration(milliseconds: 60));
        await selection.up();
        await tester.pump(const Duration(milliseconds: 250));

        expect(controller.hasSelection, isFalse);
      });

      testWidgets('applies macOS discrete wheel defaults', (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        enableSgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        await sendPointerEvent(
          tester,
          const PointerScrollEvent(
            position: Offset(24, 16),
            scrollDelta: Offset(0, -40),
          ),
        );
        debugDefaultTargetPlatformOverride = null;

        expect(sgrCodes(events), [64, 64, 64]);
      });

      testWidgets('encodes trackpad pan in all four wheel directions', (
        tester,
      ) async {
        enableSgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        final pointer = TestPointer(30, PointerDeviceKind.trackpad);
        const position = Offset(24, 16);
        await sendPointerEvent(tester, pointer.panZoomStart(position));
        await sendPointerEvent(
          tester,
          pointer.panZoomUpdate(position, pan: const Offset(0, 16)),
        );
        await sendPointerEvent(tester, pointer.panZoomUpdate(position));
        await sendPointerEvent(
          tester,
          pointer.panZoomUpdate(position, pan: const Offset(8, 0)),
        );
        await sendPointerEvent(tester, pointer.panZoomUpdate(position));
        await sendPointerEvent(tester, pointer.panZoomEnd());

        expect(sgrCodes(events), [64, 65, 66, 67]);
      });

      testWidgets('forwards trackpad pan as precision pixel movement', (
        tester,
      ) async {
        enableSgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        final pointer = TestPointer(71, PointerDeviceKind.trackpad);
        const position = Offset(24, 16);
        await sendPointerEvent(tester, pointer.panZoomStart(position));
        await sendPointerEvent(
          tester,
          pointer.panZoomUpdate(position, pan: const Offset(0, 8)),
        );

        expect(events, isEmpty);

        await sendPointerEvent(
          tester,
          pointer.panZoomUpdate(position, pan: const Offset(0, 16)),
        );
        await sendPointerEvent(tester, pointer.panZoomEnd());

        expect(sgrCodes(events), [64]);
      });

      testWidgets('keeps trackpad scroll at its sequence start position', (
        tester,
      ) async {
        enableSgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        final pointer = TestPointer(47, PointerDeviceKind.trackpad);
        const start = Offset(24, 16);
        await sendPointerEvent(tester, pointer.panZoomStart(start));
        await sendPointerEvent(
          tester,
          pointer.panZoomUpdate(
            const Offset(160, 96),
            pan: const Offset(16, 32),
          ),
        );
        await sendPointerEvent(
          tester,
          pointer.panZoomUpdate(
            const Offset(320, 192),
            pan: const Offset(32, 64),
          ),
        );
        await sendPointerEvent(tester, pointer.panZoomEnd());

        expect(sgrPositions(events), everyElement(equals((x: 4, y: 2))));
      });

      testWidgets('accumulates trackpad pan remainders independently', (
        tester,
      ) async {
        enableSgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        final pointer = TestPointer(31, PointerDeviceKind.trackpad);
        const position = Offset(24, 16);
        await sendPointerEvent(tester, pointer.panZoomStart(position));
        await sendPointerEvent(
          tester,
          pointer.panZoomUpdate(position, pan: const Offset(4, 8)),
        );
        await sendPointerEvent(
          tester,
          pointer.panZoomUpdate(position, pan: const Offset(8, 16)),
        );
        await sendPointerEvent(
          tester,
          pointer.panZoomUpdate(position, pan: const Offset(12, 24)),
        );
        await sendPointerEvent(
          tester,
          pointer.panZoomUpdate(position, pan: const Offset(16, 32)),
        );
        await sendPointerEvent(tester, pointer.panZoomEnd());

        expect(sgrCodes(events), [64, 66, 64, 66]);
      });

      testWidgets('shares wheel remainders with trackpad pan', (tester) async {
        enableSgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        await sendPointerEvent(
          tester,
          const PointerScrollEvent(
            position: Offset(24, 16),
            scrollDelta: Offset(0, -8),
          ),
        );

        final pointer = TestPointer(32, PointerDeviceKind.trackpad);
        const position = Offset(24, 16);
        await sendPointerEvent(tester, pointer.panZoomStart(position));
        await sendPointerEvent(
          tester,
          pointer.panZoomUpdate(position, pan: const Offset(0, 8)),
        );
        await sendPointerEvent(tester, pointer.panZoomEnd());

        expect(sgrCodes(events), [64]);
      });

      testWidgets('emits trackpad steps in vertical then horizontal order', (
        tester,
      ) async {
        enableSgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        final pointer = TestPointer(33, PointerDeviceKind.trackpad);
        const position = Offset(40, 32);
        await sendPointerEvent(tester, pointer.panZoomStart(position));
        await sendPointerEvent(
          tester,
          pointer.panZoomUpdate(position, pan: const Offset(-24, 32)),
        );
        await sendPointerEvent(tester, pointer.panZoomEnd());

        expect(sgrCodes(events), [64, 64, 67, 67, 67]);
      });

      testWidgets('does not claim trackpad pan with physical Shift', (
        tester,
      ) async {
        enableSgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
        final pointer = TestPointer(34, PointerDeviceKind.trackpad);
        const position = Offset(24, 16);
        await sendPointerEvent(tester, pointer.panZoomStart(position));
        await sendPointerEvent(
          tester,
          pointer.panZoomUpdate(position, pan: const Offset(0, 16)),
        );
        await sendPointerEvent(tester, pointer.panZoomEnd());
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);

        expect(events, isEmpty);
      });

      testWidgets('does not claim trackpad pan with virtual Shift', (
        tester,
      ) async {
        enableSgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;
        controller.toggleMod(const Mods.shift());

        await tester.pumpWidget(buildHandler(controller: controller));
        final pointer = TestPointer(35, PointerDeviceKind.trackpad);
        const position = Offset(24, 16);
        await sendPointerEvent(tester, pointer.panZoomStart(position));
        await sendPointerEvent(
          tester,
          pointer.panZoomUpdate(position, pan: const Offset(0, 16)),
        );
        await sendPointerEvent(tester, pointer.panZoomEnd());

        expect(events, isEmpty);
      });

      testWidgets('ignores trackpad scale and rotation without pan', (
        tester,
      ) async {
        enableSgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        final pointer = TestPointer(36, PointerDeviceKind.trackpad);
        const position = Offset(24, 16);
        await sendPointerEvent(tester, pointer.panZoomStart(position));
        await sendPointerEvent(
          tester,
          pointer.panZoomUpdate(position, scale: 1.2, rotation: 0.5),
        );
        await sendPointerEvent(tester, pointer.panZoomEnd());

        expect(events, isEmpty);
      });

      testWidgets('leaves pure trackpad scale to an enclosing recognizer', (
        tester,
      ) async {
        enableSgrMouseTracking(controller);
        var scaleUpdates = 0;

        await tester.pumpWidget(
          GestureDetector(
            onScaleUpdate: (_) => scaleUpdates++,
            child: buildHandler(controller: controller),
          ),
        );
        final pointer = TestPointer(72, PointerDeviceKind.trackpad);
        const position = Offset(24, 16);
        await sendPointerEvent(tester, pointer.panZoomStart(position));
        await sendPointerEvent(
          tester,
          pointer.panZoomUpdate(position, scale: 1.2, rotation: 0.5),
        );
        await sendPointerEvent(tester, pointer.panZoomEnd());

        expect(scaleUpdates, greaterThan(0));
      });

      testWidgets('does not claim trackpad pan with invalid metrics', (
        tester,
      ) async {
        enableSgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(
          buildHandler(
            controller: controller,
            metrics: const CellMetrics(
              cellWidth: 0,
              cellHeight: 0,
              baseline: 0,
            ),
          ),
        );
        final pointer = TestPointer(37, PointerDeviceKind.trackpad);
        const position = Offset(24, 16);
        await sendPointerEvent(tester, pointer.panZoomStart(position));
        await sendPointerEvent(
          tester,
          pointer.panZoomUpdate(position, pan: const Offset(0, 100)),
        );
        await sendPointerEvent(tester, pointer.panZoomEnd());

        expect(events, isEmpty);
      });

      testWidgets('does not claim trackpad pan when scrolling is disabled', (
        tester,
      ) async {
        enableSgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(
          buildHandler(
            controller: controller,
            scrollPhysics: const NeverScrollableScrollPhysics(),
          ),
        );
        final pointer = TestPointer(57, PointerDeviceKind.trackpad);
        const position = Offset(24, 16);
        await sendPointerEvent(tester, pointer.panZoomStart(position));
        await sendPointerEvent(
          tester,
          pointer.panZoomUpdate(position, pan: const Offset(0, 16)),
        );
        await sendPointerEvent(tester, pointer.panZoomEnd());

        expect(events, isEmpty);
      });

      testWidgets('disabling scrolling stops active trackpad inertia', (
        tester,
      ) async {
        enableSgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        const position = Offset(24, 16);
        final pointer = TestPointer(64, PointerDeviceKind.trackpad);
        await sendPointerEvent(tester, pointer.panZoomStart(position));
        await sendPointerEvent(
          tester,
          pointer.panZoomUpdate(
            position,
            pan: const Offset(0, 30),
            timeStamp: const Duration(milliseconds: 8),
          ),
        );
        await sendPointerEvent(
          tester,
          pointer.panZoomUpdate(
            position,
            pan: const Offset(0, 60),
            timeStamp: const Duration(milliseconds: 16),
          ),
        );
        await sendPointerEvent(
          tester,
          pointer.panZoomUpdate(
            position,
            pan: const Offset(0, 100),
            timeStamp: const Duration(milliseconds: 24),
          ),
        );
        await sendPointerEvent(
          tester,
          pointer.panZoomEnd(timeStamp: const Duration(milliseconds: 25)),
        );
        await tester.pump(const Duration(milliseconds: 32));

        await tester.pumpWidget(
          buildHandler(
            controller: controller,
            scrollPhysics: const NeverScrollableScrollPhysics(),
          ),
        );
        events.clear();
        await tester.pump(const Duration(milliseconds: 100));

        expect(events, isEmpty);
      });

      testWidgets('changing scroll physics stops active trackpad inertia', (
        tester,
      ) async {
        enableSgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        const position = Offset(24, 16);
        final pointer = TestPointer(69, PointerDeviceKind.trackpad);
        await sendPointerEvent(tester, pointer.panZoomStart(position));
        await sendPointerEvent(
          tester,
          pointer.panZoomUpdate(
            position,
            pan: const Offset(0, 100),
            timeStamp: const Duration(milliseconds: 16),
          ),
        );
        await sendPointerEvent(
          tester,
          pointer.panZoomEnd(timeStamp: const Duration(milliseconds: 32)),
        );
        await tester.pump(const Duration(milliseconds: 16));

        await tester.pumpWidget(
          buildHandler(
            controller: controller,
            scrollPhysics: const BouncingScrollPhysics(),
          ),
        );
        events.clear();
        await tester.pump(const Duration(milliseconds: 100));

        expect(events, isEmpty);
      });

      testWidgets('keeps an accepted trackpad pan after virtual Shift', (
        tester,
      ) async {
        enableSgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        final pointer = TestPointer(38, PointerDeviceKind.trackpad);
        const position = Offset(24, 16);
        await sendPointerEvent(tester, pointer.panZoomStart(position));
        controller.toggleMod(const Mods.shift());
        await sendPointerEvent(
          tester,
          pointer.panZoomUpdate(position, pan: const Offset(0, 16)),
        );
        await sendPointerEvent(tester, pointer.panZoomEnd());

        expect(sgrCodes(events), [64]);
      });

      testWidgets('clears trackpad ownership at the end of a sequence', (
        tester,
      ) async {
        enableSgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        final pointer = TestPointer(39, PointerDeviceKind.trackpad);
        const position = Offset(24, 16);
        await sendPointerEvent(tester, pointer.panZoomStart(position));
        await sendPointerEvent(
          tester,
          pointer.panZoomUpdate(position, pan: const Offset(0, 16)),
        );
        await sendPointerEvent(tester, pointer.panZoomEnd());
        await sendPointerEvent(tester, pointer.panZoomStart(position));
        await sendPointerEvent(
          tester,
          pointer.panZoomUpdate(position, pan: const Offset(0, 16)),
        );
        await sendPointerEvent(tester, pointer.panZoomEnd());

        expect(sgrCodes(events), [64, 64]);
      });

      testWidgets('accepts vertical pan while prior inertia is active', (
        tester,
      ) async {
        enableSgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        const position = Offset(24, 16);
        final firstPointer = TestPointer(40, PointerDeviceKind.trackpad);
        await sendPointerEvent(tester, firstPointer.panZoomStart(position));
        await sendPointerEvent(
          tester,
          firstPointer.panZoomUpdate(
            position,
            pan: const Offset(0, 30),
            timeStamp: const Duration(milliseconds: 8),
          ),
        );
        await sendPointerEvent(
          tester,
          firstPointer.panZoomUpdate(
            position,
            pan: const Offset(0, 60),
            timeStamp: const Duration(milliseconds: 16),
          ),
        );
        await sendPointerEvent(
          tester,
          firstPointer.panZoomUpdate(
            position,
            pan: const Offset(0, 100),
            timeStamp: const Duration(milliseconds: 24),
          ),
        );
        await sendPointerEvent(
          tester,
          firstPointer.panZoomEnd(timeStamp: const Duration(milliseconds: 25)),
        );
        await tester.pump(const Duration(milliseconds: 32));
        final secondPointer = TestPointer(41, PointerDeviceKind.trackpad);
        await sendPointerEvent(
          tester,
          secondPointer.panZoomStart(
            position,
            timeStamp: const Duration(milliseconds: 57),
          ),
        );
        events.clear();
        await sendPointerEvent(
          tester,
          secondPointer.panZoomUpdate(
            position,
            pan: const Offset(0, -100),
            timeStamp: const Duration(milliseconds: 73),
          ),
        );
        await sendPointerEvent(
          tester,
          secondPointer.panZoomEnd(timeStamp: const Duration(milliseconds: 89)),
        );

        expect(sgrCodes(events), allOf(isNotEmpty, everyElement(equals(65))));
      });

      testWidgets('accepts horizontal pan while prior inertia is active', (
        tester,
      ) async {
        enableSgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        const position = Offset(24, 16);
        final firstPointer = TestPointer(42, PointerDeviceKind.trackpad);
        await sendPointerEvent(tester, firstPointer.panZoomStart(position));
        await sendPointerEvent(
          tester,
          firstPointer.panZoomUpdate(
            position,
            pan: const Offset(30, 0),
            timeStamp: const Duration(milliseconds: 8),
          ),
        );
        await sendPointerEvent(
          tester,
          firstPointer.panZoomUpdate(
            position,
            pan: const Offset(60, 0),
            timeStamp: const Duration(milliseconds: 16),
          ),
        );
        await sendPointerEvent(
          tester,
          firstPointer.panZoomUpdate(
            position,
            pan: const Offset(100, 0),
            timeStamp: const Duration(milliseconds: 24),
          ),
        );
        await sendPointerEvent(
          tester,
          firstPointer.panZoomEnd(timeStamp: const Duration(milliseconds: 25)),
        );
        await tester.pump(const Duration(milliseconds: 32));
        final secondPointer = TestPointer(43, PointerDeviceKind.trackpad);
        await sendPointerEvent(
          tester,
          secondPointer.panZoomStart(
            position,
            timeStamp: const Duration(milliseconds: 57),
          ),
        );
        events.clear();
        await sendPointerEvent(
          tester,
          secondPointer.panZoomUpdate(
            position,
            pan: const Offset(-100, 0),
            timeStamp: const Duration(milliseconds: 73),
          ),
        );
        await sendPointerEvent(
          tester,
          secondPointer.panZoomEnd(timeStamp: const Duration(milliseconds: 89)),
        );

        expect(sgrCodes(events), allOf(isNotEmpty, everyElement(equals(67))));
      });

      testWidgets('accepts a replacement pan after inertia cancellation', (
        tester,
      ) async {
        enableSgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        const position = Offset(24, 16);
        final firstPointer = TestPointer(51, PointerDeviceKind.trackpad);
        await sendPointerEvent(tester, firstPointer.panZoomStart(position));
        await sendPointerEvent(
          tester,
          firstPointer.panZoomUpdate(
            position,
            pan: const Offset(30, 0),
            timeStamp: const Duration(milliseconds: 8),
          ),
        );
        await sendPointerEvent(
          tester,
          firstPointer.panZoomUpdate(
            position,
            pan: const Offset(60, 0),
            timeStamp: const Duration(milliseconds: 16),
          ),
        );
        await sendPointerEvent(
          tester,
          firstPointer.panZoomUpdate(
            position,
            pan: const Offset(100, 0),
            timeStamp: const Duration(milliseconds: 24),
          ),
        );
        await sendPointerEvent(
          tester,
          firstPointer.panZoomEnd(timeStamp: const Duration(milliseconds: 25)),
        );
        await tester.pump(const Duration(milliseconds: 32));
        final secondPointer = TestPointer(52, PointerDeviceKind.trackpad);
        await sendPointerEvent(
          tester,
          firstPointer.scrollInertiaCancel(
            timeStamp: const Duration(milliseconds: 56),
          ),
        );
        await sendPointerEvent(
          tester,
          secondPointer.panZoomStart(
            position,
            timeStamp: const Duration(milliseconds: 57),
          ),
        );
        events.clear();

        await sendPointerEvent(
          tester,
          secondPointer.panZoomUpdate(
            position,
            pan: const Offset(-100, 0),
            timeStamp: const Duration(milliseconds: 73),
          ),
        );
        await sendPointerEvent(
          tester,
          secondPointer.panZoomEnd(timeStamp: const Duration(milliseconds: 89)),
        );

        expect(sgrCodes(events), allOf(isNotEmpty, everyElement(equals(67))));
      });

      testWidgets('replacement inertia uses the new pan start position', (
        tester,
      ) async {
        enableSgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        const firstPosition = Offset(24, 16);
        final firstPointer = TestPointer(49, PointerDeviceKind.trackpad);
        await sendPointerEvent(
          tester,
          firstPointer.panZoomStart(firstPosition),
        );
        await sendPointerEvent(
          tester,
          firstPointer.panZoomUpdate(
            firstPosition,
            pan: const Offset(30, 0),
            timeStamp: const Duration(milliseconds: 8),
          ),
        );
        await sendPointerEvent(
          tester,
          firstPointer.panZoomUpdate(
            firstPosition,
            pan: const Offset(60, 0),
            timeStamp: const Duration(milliseconds: 16),
          ),
        );
        await sendPointerEvent(
          tester,
          firstPointer.panZoomUpdate(
            firstPosition,
            pan: const Offset(100, 0),
            timeStamp: const Duration(milliseconds: 24),
          ),
        );
        await sendPointerEvent(
          tester,
          firstPointer.panZoomEnd(timeStamp: const Duration(milliseconds: 25)),
        );
        await tester.pump(const Duration(milliseconds: 32));

        const secondPosition = Offset(160, 96);
        final secondPointer = TestPointer(50, PointerDeviceKind.trackpad);
        await sendPointerEvent(
          tester,
          secondPointer.panZoomStart(
            secondPosition,
            timeStamp: const Duration(milliseconds: 57),
          ),
        );
        events.clear();
        await sendPointerEvent(
          tester,
          secondPointer.panZoomUpdate(
            secondPosition,
            pan: const Offset(-30, 0),
            timeStamp: const Duration(milliseconds: 65),
          ),
        );
        await sendPointerEvent(
          tester,
          secondPointer.panZoomUpdate(
            secondPosition,
            pan: const Offset(-60, 0),
            timeStamp: const Duration(milliseconds: 73),
          ),
        );
        await sendPointerEvent(
          tester,
          secondPointer.panZoomUpdate(
            secondPosition,
            pan: const Offset(-100, 0),
            timeStamp: const Duration(milliseconds: 81),
          ),
        );
        await sendPointerEvent(
          tester,
          secondPointer.panZoomEnd(timeStamp: const Duration(milliseconds: 82)),
        );
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          sgrPositions(events),
          allOf(isNotEmpty, everyElement(equals((x: 21, y: 7)))),
        );
      });

      testWidgets('horizontal inertia settles at a stable endpoint', (
        tester,
      ) async {
        enableSgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        const position = Offset(24, 16);
        final pointer = TestPointer(45, PointerDeviceKind.trackpad);
        await sendPointerEvent(tester, pointer.panZoomStart(position));
        await sendPointerEvent(
          tester,
          pointer.panZoomUpdate(
            position,
            pan: const Offset(100, 0),
            timeStamp: const Duration(milliseconds: 16),
          ),
        );
        await sendPointerEvent(
          tester,
          pointer.panZoomEnd(timeStamp: const Duration(milliseconds: 32)),
        );
        await tester.pump(const Duration(milliseconds: 32));
        final movingEventCount = events.length;
        expect(movingEventCount, greaterThan(0));

        await tester.pump(const Duration(seconds: 10));
        final settledEventCount = events.length;
        await tester.pump(const Duration(seconds: 1));

        expect(events.length, settledEventCount);
      });

      testWidgets('cancels horizontal inertia on an inertia cancel signal', (
        tester,
      ) async {
        enableSgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        const position = Offset(24, 16);
        final pointer = TestPointer(46, PointerDeviceKind.trackpad);
        await sendPointerEvent(tester, pointer.panZoomStart(position));
        await sendPointerEvent(
          tester,
          pointer.panZoomUpdate(
            position,
            pan: const Offset(100, 0),
            timeStamp: const Duration(milliseconds: 16),
          ),
        );
        await sendPointerEvent(
          tester,
          pointer.panZoomEnd(timeStamp: const Duration(milliseconds: 32)),
        );
        await tester.pump(const Duration(milliseconds: 32));
        final movingEventCount = events.length;
        expect(movingEventCount, greaterThan(0));

        await sendPointerEvent(
          tester,
          pointer.scrollInertiaCancel(
            timeStamp: const Duration(milliseconds: 64),
          ),
        );
        await tester.pump(const Duration(seconds: 1));

        expect(events.length, movingEventCount);
      });

      testWidgets('wheel input interrupts horizontal inertia immediately', (
        tester,
      ) async {
        enableSgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        const position = Offset(24, 16);
        final pointer = TestPointer(48, PointerDeviceKind.trackpad);
        await sendPointerEvent(tester, pointer.panZoomStart(position));
        await sendPointerEvent(
          tester,
          pointer.panZoomUpdate(
            position,
            pan: const Offset(30, 0),
            timeStamp: const Duration(milliseconds: 8),
          ),
        );
        await sendPointerEvent(
          tester,
          pointer.panZoomUpdate(
            position,
            pan: const Offset(60, 0),
            timeStamp: const Duration(milliseconds: 16),
          ),
        );
        await sendPointerEvent(
          tester,
          pointer.panZoomUpdate(
            position,
            pan: const Offset(100, 0),
            timeStamp: const Duration(milliseconds: 24),
          ),
        );
        await sendPointerEvent(
          tester,
          pointer.panZoomEnd(timeStamp: const Duration(milliseconds: 25)),
        );
        await tester.pump(const Duration(milliseconds: 32));
        events.clear();

        await tester.sendEventToBinding(
          const PointerScrollEvent(
            position: position,
            scrollDelta: Offset(80, 0),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(sgrCodes(events), allOf(isNotEmpty, everyElement(equals(67))));
      });

      testWidgets('zero wheel input preserves horizontal inertia', (
        tester,
      ) async {
        enableSgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        const position = Offset(24, 16);
        final pointer = TestPointer(63, PointerDeviceKind.trackpad);
        await sendPointerEvent(tester, pointer.panZoomStart(position));
        await sendPointerEvent(
          tester,
          pointer.panZoomUpdate(
            position,
            pan: const Offset(30, 0),
            timeStamp: const Duration(milliseconds: 8),
          ),
        );
        await sendPointerEvent(
          tester,
          pointer.panZoomUpdate(
            position,
            pan: const Offset(60, 0),
            timeStamp: const Duration(milliseconds: 16),
          ),
        );
        await sendPointerEvent(
          tester,
          pointer.panZoomUpdate(
            position,
            pan: const Offset(100, 0),
            timeStamp: const Duration(milliseconds: 24),
          ),
        );
        await sendPointerEvent(
          tester,
          pointer.panZoomEnd(timeStamp: const Duration(milliseconds: 25)),
        );
        await tester.pump(const Duration(milliseconds: 32));
        events.clear();

        await sendPointerEvent(
          tester,
          const PointerScrollEvent(position: position),
        );
        await tester.pump(const Duration(milliseconds: 100));

        expect(events, isNotEmpty);
      });

      testWidgets('disposes active inertia when region unmounts', (
        tester,
      ) async {
        enableSgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        const position = Offset(24, 16);
        final pointer = TestPointer(44, PointerDeviceKind.trackpad);
        await sendPointerEvent(tester, pointer.panZoomStart(position));
        await sendPointerEvent(
          tester,
          pointer.panZoomUpdate(
            position,
            pan: const Offset(0, 100),
            timeStamp: const Duration(milliseconds: 16),
          ),
        );
        await sendPointerEvent(
          tester,
          pointer.panZoomEnd(timeStamp: const Duration(milliseconds: 32)),
        );
        await tester.pump(const Duration(milliseconds: 16));

        await tester.pumpWidget(const SizedBox());
        events.clear();
        await tester.pump(const Duration(seconds: 1));

        expect(events, isEmpty);
      });

      testWidgets('accumulates wheel remainders independently by axis', (
        tester,
      ) async {
        enableSgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        await sendPointerEvent(
          tester,
          const PointerScrollEvent(
            position: Offset(24, 16),
            scrollDelta: Offset(4, -8),
          ),
        );
        await sendPointerEvent(
          tester,
          const PointerScrollEvent(
            position: Offset(24, 16),
            scrollDelta: Offset(4, -8),
          ),
        );

        expect(sgrCodes(events), [64, 67]);
      });

      testWidgets('emits multiple wheel steps in axis order', (tester) async {
        enableSgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        await sendPointerEvent(
          tester,
          const PointerScrollEvent(
            position: Offset(24, 16),
            scrollDelta: Offset(-24, 32),
          ),
        );

        expect(sgrCodes(events), [65, 65, 66, 66, 66]);
      });

      testWidgets('carries signed wheel remainders across direction changes', (
        tester,
      ) async {
        enableSgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        await sendPointerEvent(
          tester,
          const PointerScrollEvent(position: Offset(24, 16)),
        );
        await sendPointerEvent(
          tester,
          const PointerScrollEvent(
            position: Offset(24, 16),
            scrollDelta: Offset(0, -12),
          ),
        );
        await sendPointerEvent(
          tester,
          const PointerScrollEvent(
            position: Offset(24, 16),
            scrollDelta: Offset(0, 20),
          ),
        );
        await sendPointerEvent(
          tester,
          const PointerScrollEvent(
            position: Offset(24, 16),
            scrollDelta: Offset(0, 8),
          ),
        );

        expect(sgrCodes(events), [65]);
      });

      testWidgets('uses the scroll signal local position', (tester) async {
        enableSgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        await sendPointerEvent(
          tester,
          const PointerScrollEvent(
            position: Offset(40, 32),
            scrollDelta: Offset(0, -16),
          ),
        );

        expect(utf8.decode(events.single), '\x1b[<64;6;3M');
      });

      testWidgets('ignores wheel input when metrics are invalid', (
        tester,
      ) async {
        enableSgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(
          buildHandler(
            controller: controller,
            metrics: const CellMetrics(
              cellWidth: 0,
              cellHeight: 0,
              baseline: 0,
            ),
          ),
        );
        await sendPointerEvent(
          tester,
          const PointerScrollEvent(
            position: Offset(24, 16),
            scrollDelta: Offset(0, -100),
          ),
        );

        expect(events, isEmpty);
      });

      testWidgets('resets wheel remainder when metrics change', (tester) async {
        enableSgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        await sendPointerEvent(
          tester,
          const PointerScrollEvent(
            position: Offset(24, 16),
            scrollDelta: Offset(0, -8),
          ),
        );
        await tester.pumpWidget(
          buildHandler(
            controller: controller,
            metrics: const CellMetrics(
              cellWidth: 8,
              cellHeight: 8,
              baseline: 6,
            ),
          ),
        );
        await sendPointerEvent(
          tester,
          const PointerScrollEvent(
            position: Offset(24, 16),
            scrollDelta: Offset(0, -8),
          ),
        );

        expect(sgrCodes(events), [64]);
      });

      testWidgets('resets wheel remainder when tracking ends', (tester) async {
        enableSgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        await sendPointerEvent(
          tester,
          const PointerScrollEvent(
            position: Offset(24, 16),
            scrollDelta: Offset(0, -8),
          ),
        );
        writeToTerminal(controller, '\x1b[?1000l');
        await tester.pump();
        writeToTerminal(controller, '\x1b[?1000h\x1b[?1006h');
        await tester.pump();
        await sendPointerEvent(
          tester,
          const PointerScrollEvent(
            position: Offset(24, 16),
            scrollDelta: Offset(0, -8),
          ),
        );
        await sendPointerEvent(
          tester,
          const PointerScrollEvent(
            position: Offset(24, 16),
            scrollDelta: Offset(0, -8),
          ),
        );

        expect(sgrCodes(events), [64]);
      });

      testWidgets('uses live mouse tracking before claiming trackpad pan', (
        tester,
      ) async {
        writeToTerminal(controller, 'hello');
        enableSgrMouseTracking(controller);
        controller.selectAll();

        await tester.pumpWidget(buildHandler(controller: controller));
        writeToTerminal(controller, '\x1b[?1000l');
        final pointer = TestPointer(60, PointerDeviceKind.trackpad);
        const position = Offset(24, 16);
        await sendPointerEvent(tester, pointer.panZoomStart(position));
        await sendPointerEvent(
          tester,
          pointer.panZoomUpdate(position, pan: const Offset(0, 16)),
        );
        await sendPointerEvent(tester, pointer.panZoomEnd());

        expect(controller.hasSelection, isTrue);
      });

      testWidgets('physical Shift keeps selection ownership after release', (
        tester,
      ) async {
        enableSgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
        final gesture = await mouseDown(
          tester,
          const Offset(24, 16),
          pointer: 17,
        );
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
        await gesture.moveBy(const Offset(40, 16));
        await gesture.up();

        expect(controller.hasSelection, isTrue);
      });

      testWidgets('tracked touch uses an independent left-button sequence', (
        tester,
      ) async {
        enableAnySgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        await sendPointerEvent(
          tester,
          const PointerDownEvent(
            pointer: 13,
            position: Offset(24, 16),
            buttons: 0,
          ),
        );
        await sendPointerEvent(
          tester,
          const PointerMoveEvent(pointer: 13, position: Offset(32, 16)),
        );
        await sendPointerEvent(
          tester,
          const PointerUpEvent(pointer: 13, position: Offset(24, 16)),
        );

        expect(sgrCodes(events), [0, 0]);
      });

      testWidgets('tracked touch long press remains terminal-owned', (
        tester,
      ) async {
        enableAnySgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        final gesture = await tester.startGesture(
          const Offset(24, 16),
          pointer: 1013,
        );
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 1));

        expect(controller.hasSelection, isFalse);

        await gesture.up();

        expect(controller.hasSelection, isFalse);
        expect(sgrCodes(events), [0, 0]);
      });

      testWidgets('tracked touch scroll keeps its first contact position', (
        tester,
      ) async {
        enableAnySgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        const start = Offset(24, 16);
        const second = Offset(160, 96);
        final firstPointer = TestPointer(53);
        final secondPointer = TestPointer(54);
        await sendPointerEvent(tester, firstPointer.down(start));
        await sendPointerEvent(
          tester,
          firstPointer.move(
            start.translate(0, -64),
            timeStamp: const Duration(milliseconds: 8),
          ),
        );
        events.clear();

        await sendPointerEvent(
          tester,
          secondPointer.down(
            second,
            timeStamp: const Duration(milliseconds: 16),
          ),
        );
        await sendPointerEvent(
          tester,
          secondPointer.move(
            second.translate(0, -64),
            timeStamp: const Duration(milliseconds: 24),
          ),
        );

        expect(events, isNotEmpty);
        expect(sgrPositions(events), everyElement(equals((x: 4, y: 2))));

        events.clear();
        await sendPointerEvent(tester, secondPointer.up());
        await sendPointerEvent(tester, firstPointer.up());
      });

      testWidgets('rejects trackpad pan while touch scroll is active', (
        tester,
      ) async {
        enableAnySgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        const touchPosition = Offset(24, 48);
        final touch = TestPointer(65);
        await sendPointerEvent(tester, touch.down(touchPosition));
        await sendPointerEvent(
          tester,
          touch.move(
            touchPosition.translate(0, -64),
            timeStamp: const Duration(milliseconds: 16),
          ),
        );
        events.clear();

        const trackpadPosition = Offset(160, 96);
        final trackpad = TestPointer(66, PointerDeviceKind.trackpad);
        await sendPointerEvent(
          tester,
          trackpad.panZoomStart(
            trackpadPosition,
            timeStamp: const Duration(milliseconds: 24),
          ),
        );
        await sendPointerEvent(
          tester,
          trackpad.panZoomUpdate(
            trackpadPosition,
            pan: const Offset(0, 32),
            timeStamp: const Duration(milliseconds: 32),
          ),
        );
        await sendPointerEvent(
          tester,
          trackpad.panZoomEnd(timeStamp: const Duration(milliseconds: 40)),
        );
        final overlappingOutput = List<Uint8List>.of(events);
        await sendPointerEvent(
          tester,
          touch.up(timeStamp: const Duration(milliseconds: 48)),
        );

        expect(overlappingOutput, isEmpty);
      });

      testWidgets('keeps touch scroll active after overlapping trackpad pan', (
        tester,
      ) async {
        enableAnySgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        const touchPosition = Offset(24, 48);
        final touch = TestPointer(67);
        await sendPointerEvent(tester, touch.down(touchPosition));
        await sendPointerEvent(
          tester,
          touch.move(
            touchPosition.translate(0, -64),
            timeStamp: const Duration(milliseconds: 16),
          ),
        );

        const trackpadPosition = Offset(160, 96);
        final trackpad = TestPointer(68, PointerDeviceKind.trackpad);
        await sendPointerEvent(
          tester,
          trackpad.panZoomStart(
            trackpadPosition,
            timeStamp: const Duration(milliseconds: 24),
          ),
        );
        await sendPointerEvent(
          tester,
          trackpad.panZoomUpdate(
            trackpadPosition,
            pan: const Offset(0, 32),
            timeStamp: const Duration(milliseconds: 32),
          ),
        );
        await sendPointerEvent(
          tester,
          trackpad.panZoomEnd(timeStamp: const Duration(milliseconds: 40)),
        );
        events.clear();

        await sendPointerEvent(
          tester,
          touch.move(
            touchPosition.translate(0, -128),
            timeStamp: const Duration(milliseconds: 48),
          ),
        );
        final continuedOutput = List<Uint8List>.of(events);
        await sendPointerEvent(
          tester,
          touch.up(timeStamp: const Duration(milliseconds: 56)),
        );

        expect(continuedOutput, isNotEmpty);
      });

      testWidgets('honors the configured multi-touch drag strategy', (
        tester,
      ) async {
        enableAnySgrMouseTracking(controller);
        final events = <Uint8List>[];
        controller.onOutput = events.add;
        final behavior = const ScrollBehavior().copyWith(
          multitouchDragStrategy: MultitouchDragStrategy.sumAllPointers,
        );

        await tester.pumpWidget(
          ScrollConfiguration(
            behavior: behavior,
            child: buildHandler(controller: controller),
          ),
        );
        const position = Offset(24, 48);
        final first = TestPointer(58);
        final second = TestPointer(59);
        await sendPointerEvent(tester, first.down(position));
        await sendPointerEvent(
          tester,
          first.move(
            position.translate(0, -32),
            timeStamp: const Duration(milliseconds: 16),
          ),
        );
        events.clear();
        await sendPointerEvent(
          tester,
          second.down(
            position.translate(16, 0),
            timeStamp: const Duration(milliseconds: 24),
          ),
        );
        await sendPointerEvent(
          tester,
          first.move(
            position.translate(0, -64),
            timeStamp: const Duration(milliseconds: 32),
          ),
        );

        await sendPointerEvent(
          tester,
          first.up(timeStamp: const Duration(milliseconds: 40)),
        );
        await sendPointerEvent(
          tester,
          second.up(timeStamp: const Duration(milliseconds: 48)),
        );

        expect(events, isNotEmpty);
      });

      testWidgets('click fires press and release when mode is normal', (
        tester,
      ) async {
        enableMouseTracking(controller);

        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));

        final gesture = await mouseDown(tester, const Offset(24, 16));
        await gesture.up();

        expect(events.length, 2);
      });

      testWidgets('click fires press only when mode is x10', (tester) async {
        enableMouseTracking(controller, mode: .x10);

        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));

        final gesture = await mouseDown(tester, const Offset(24, 16));
        await gesture.up();

        expect(events.length, 1);
      });

      testWidgets('no events when mode is none', (tester) async {
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));

        final gesture = await mouseDown(tester, const Offset(24, 16));
        await gesture.up();

        expect(events, isEmpty);
      });
    });

    group('alternate scroll mode', () {
      testWidgets('leaves wheel selection intact when disabled', (
        tester,
      ) async {
        writeToTerminal(controller, '\x1b[?1049h\x1b[?1007lhello');
        controller.selectAll();

        await tester.pumpWidget(buildHandler(controller: controller));
        await sendPointerEvent(
          tester,
          const PointerScrollEvent(
            position: Offset(24, 16),
            scrollDelta: Offset(0, -16),
          ),
        );

        expect(controller.hasSelection, isTrue);
      });

      testWidgets('uses live alternate-scroll mode before claiming pan', (
        tester,
      ) async {
        writeToTerminal(controller, '\x1b[?1049hhello');
        controller.selectAll();

        await tester.pumpWidget(buildHandler(controller: controller));
        writeToTerminal(controller, '\x1b[?1007l');
        final pointer = TestPointer(61, PointerDeviceKind.trackpad);
        const position = Offset(24, 16);
        await sendPointerEvent(tester, pointer.panZoomStart(position));
        await sendPointerEvent(
          tester,
          pointer.panZoomUpdate(position, pan: const Offset(0, 16)),
        );
        await sendPointerEvent(tester, pointer.panZoomEnd());

        expect(controller.hasSelection, isTrue);
      });

      testWidgets('leaves selection intact for horizontal wheel input', (
        tester,
      ) async {
        writeToTerminal(controller, '\x1b[?1049hhello');
        controller.selectAll();

        await tester.pumpWidget(buildHandler(controller: controller));
        await sendPointerEvent(
          tester,
          const PointerScrollEvent(
            position: Offset(24, 16),
            scrollDelta: Offset(8, 0),
          ),
        );

        expect(controller.hasSelection, isTrue);
      });

      testWidgets('releases unsupported horizontal wheel input to ancestors', (
        tester,
      ) async {
        writeToTerminal(controller, '\x1b[?1049hhello');
        var resolvedByAncestor = false;

        await tester.pumpWidget(
          Listener(
            onPointerSignal: (event) => GestureBinding
                .instance
                .pointerSignalResolver
                .register(event, (_) => resolvedByAncestor = true),
            child: buildHandler(controller: controller),
          ),
        );
        await sendPointerEvent(
          tester,
          const PointerScrollEvent(
            position: Offset(24, 16),
            scrollDelta: Offset(8, 0),
          ),
        );

        expect(resolvedByAncestor, isTrue);
      });

      testWidgets('releases unsupported horizontal trackpad pan to ancestors', (
        tester,
      ) async {
        writeToTerminal(controller, '\x1b[?1049hhello');
        var ancestorDelta = 0.0;

        await tester.pumpWidget(
          GestureDetector(
            onHorizontalDragUpdate: (details) =>
                ancestorDelta += details.delta.dx,
            child: buildHandler(controller: controller),
          ),
        );
        final pointer = TestPointer(69, PointerDeviceKind.trackpad);
        const position = Offset(24, 16);
        await sendPointerEvent(tester, pointer.panZoomStart(position));
        await sendPointerEvent(
          tester,
          pointer.panZoomUpdate(position, pan: const Offset(32, 0)),
        );
        await sendPointerEvent(
          tester,
          pointer.panZoomUpdate(position, pan: const Offset(64, 0)),
        );
        await sendPointerEvent(tester, pointer.panZoomEnd());

        expect(ancestorDelta.abs(), greaterThan(0));
      });

      testWidgets('claims supported vertical trackpad pan before ancestors', (
        tester,
      ) async {
        writeToTerminal(controller, '\x1b[?1049hhello');
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(
          GestureDetector(
            onVerticalDragUpdate: (_) {},
            child: buildHandler(controller: controller),
          ),
        );
        final pointer = TestPointer(70, PointerDeviceKind.trackpad);
        const position = Offset(24, 16);
        await sendPointerEvent(tester, pointer.panZoomStart(position));
        await sendPointerEvent(
          tester,
          pointer.panZoomUpdate(position, pan: const Offset(0, 32)),
        );
        await sendPointerEvent(
          tester,
          pointer.panZoomUpdate(position, pan: const Offset(0, 64)),
        );
        await sendPointerEvent(tester, pointer.panZoomEnd());

        expect(events, isNotEmpty);
      });

      testWidgets('leaves selection intact for horizontal trackpad pan', (
        tester,
      ) async {
        writeToTerminal(controller, '\x1b[?1049hhello');
        controller.selectAll();

        await tester.pumpWidget(buildHandler(controller: controller));
        final pointer = TestPointer(55, PointerDeviceKind.trackpad);
        const position = Offset(24, 16);
        await sendPointerEvent(tester, pointer.panZoomStart(position));
        await sendPointerEvent(
          tester,
          pointer.panZoomUpdate(position, pan: const Offset(16, 0)),
        );
        await sendPointerEvent(tester, pointer.panZoomEnd());

        expect(controller.hasSelection, isTrue);
      });

      testWidgets('Shift bypasses tracked alternate-screen scrolling', (
        tester,
      ) async {
        writeToTerminal(controller, '\x1b[?1049hhello');
        enableSgrMouseTracking(controller);
        controller.selectAll();
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(buildHandler(controller: controller));
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
        final pointer = TestPointer(56, PointerDeviceKind.trackpad);
        const position = Offset(24, 16);
        await sendPointerEvent(tester, pointer.panZoomStart(position));
        await sendPointerEvent(
          tester,
          pointer.panZoomUpdate(position, pan: const Offset(0, 16)),
        );
        await sendPointerEvent(tester, pointer.panZoomEnd());
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);

        expect(events, isEmpty);
        expect(controller.hasSelection, isTrue);
      });
    });
  });
}

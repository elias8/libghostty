@Tags(['ffi'])
library;

import 'package:flterm/src/controller/terminal_controller.dart'
    show TerminalController, ViewAttachment;
import 'package:flterm/src/foundation.dart'
    show CellMetrics, SurfaceMeasurement, TerminalConfig;
import 'package:flterm/src/input/selection_handle_target.dart'
    show SelectionHandleTarget;
import 'package:flterm/src/input/selection_handles.dart'
    show TerminalSelectionHandles;
import 'package:flterm/src/input/selection_session.dart'
    show SelectionAutoscrollPolicy, SelectionEndpoint, SelectionInteraction;
import 'package:flutter/foundation.dart'
    show ChangeNotifier, Listenable, ValueListenable;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart' show Mods, PointTag, Position;
import 'package:material_ui/material_ui.dart';

void main() {
  group('TerminalSelectionHandles', () {
    late _Fixture subject;

    setUp(() {
      subject = _Fixture();
      addTearDown(subject.dispose);
    });

    group('visibility', () {
      testWidgets('shows both handles for an active touch selection', (
        tester,
      ) async {
        subject.select();

        await subject.pump(tester);

        expect(find.byKey(_Fixture.startHandle), findsOneWidget);
        expect(find.byKey(_Fixture.endHandle), findsOneWidget);
      });

      testWidgets('hides handles when disabled', (tester) async {
        subject.select();

        await subject.pump(tester, visible: false);

        expect(find.byKey(_Fixture.startHandle), findsNothing);
      });

      testWidgets('hides handles on unsupported platforms', (tester) async {
        subject.select();

        await subject.pump(tester, platform: TargetPlatform.linux);

        expect(find.byKey(_Fixture.startHandle), findsNothing);
      });

      testWidgets('hides handles when the selection clears', (tester) async {
        subject.select();
        await subject.pump(tester);

        subject.controller.clearSelection();
        await tester.pump();

        expect(find.byKey(_Fixture.startHandle), findsNothing);
      });

      testWidgets('stays behind later stack children', (tester) async {
        var foregroundTapped = false;
        subject.select();
        await subject.pump(
          tester,
          foreground: GestureDetector(
            behavior: .opaque,
            onTap: () => foregroundTapped = true,
          ),
        );

        await tester.tapAt(tester.getCenter(find.byKey(_Fixture.startHandle)));

        expect(foregroundTapped, isTrue);
      });
    });

    group('endpoint drag', () {
      testWidgets('moves only the dragged endpoint', (tester) async {
        subject.select();
        await subject.pump(tester);
        final origin = tester.getTopLeft(find.byType(TerminalSelectionHandles));
        final drag = await subject.startDrag(tester, _Fixture.startHandle);

        await drag.moveTo(origin + const Offset(1, 16));
        await drag.end();
        await tester.pump();

        final selection = subject.selection.selection!;
        expect(
          selection.start.positionIn(.viewport),
          const Position(row: 0, col: 0),
        );
        expect(
          selection.end.positionIn(.viewport),
          const Position(row: 1, col: 6),
        );
      });

      testWidgets('keeps collapsed endpoints independently draggable', (
        tester,
      ) async {
        subject.select(
          start: const Position(row: 1, col: 3),
          end: const Position(row: 1, col: 3),
        );
        await subject.pump(tester);

        final start = await subject.startDrag(tester, _Fixture.startHandle);
        await start.moveBy(const Offset(-16, 0));
        await start.end();
        await tester.pump();
        final end = await subject.startDrag(tester, _Fixture.endHandle);
        await end.moveBy(const Offset(16, 0));
        await end.end();
        await tester.pump();

        final selection = subject.selection.selection!;
        expect(
          selection.start.positionIn(.viewport),
          const Position(row: 1, col: 1),
        );
        expect(
          selection.end.positionIn(.viewport),
          const Position(row: 1, col: 5),
        );
      });
    });

    group('selection shape', () {
      testWidgets('uses virtual Alt active before the drag', (tester) async {
        subject.select();
        subject.controller.toggleMod(const Mods.alt());
        await subject.pump(tester);
        final drag = await subject.startDrag(tester, _Fixture.endHandle);

        await drag.moveBy(const Offset(8, 0));

        expect(subject.selection.selection!.rectangle, isTrue);
      });

      testWidgets('tracks virtual Alt throughout a drag', (tester) async {
        subject.select();
        await subject.pump(tester);
        final drag = await subject.startDrag(tester, _Fixture.endHandle);

        subject.controller.toggleMod(const Mods.alt());
        await drag.moveBy(const Offset(8, 0));
        expect(subject.selection.selection!.rectangle, isTrue);

        subject.controller.toggleMod(const Mods.alt());
        await drag.moveBy(const Offset(8, 0));
        expect(subject.selection.selection!.rectangle, isFalse);
      });

      testWidgets('tracks physical Alt throughout a drag', (tester) async {
        subject.select();
        await subject.pump(tester);
        final drag = await subject.startDrag(tester, _Fixture.endHandle);
        await drag.moveBy(const Offset(1, 0));

        await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
        addTearDown(HardwareKeyboard.instance.clearState);
        expect(subject.selection.selection!.rectangle, isTrue);

        await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
        expect(subject.selection.selection!.rectangle, isFalse);
      });
    });

    group('magnifier', () {
      Future<(_TestDrag, _TestDrag)> startOverlappingHandleDrags(
        WidgetTester tester,
      ) async {
        final configuration = TextMagnifierConfiguration(
          magnifierBuilder: (_, _, _) => const Text('magnifier'),
        );
        subject.select();
        await subject.pump(tester, magnifierConfiguration: configuration);
        final start = await subject.startDrag(tester, _Fixture.startHandle);
        final end = await subject.startDrag(tester, _Fixture.endHandle);
        return (start, end);
      }

      testWidgets('keeps one lens during overlapping handle drags', (
        tester,
      ) async {
        await startOverlappingHandleDrags(tester);

        await tester.pump();

        expect(find.text('magnifier'), findsOneWidget);
      });

      testWidgets('hides the lens after overlapping handle drags end', (
        tester,
      ) async {
        final (start, end) = await startOverlappingHandleDrags(tester);

        await end.end();
        await start.end();
        await tester.pump();

        expect(find.text('magnifier'), findsNothing);
      });

      testWidgets('positions the magnifier in screen coordinates', (
        tester,
      ) async {
        const lens = ValueKey('selection-magnifier-lens');
        final configuration = TextMagnifierConfiguration(
          magnifierBuilder: (_, _, _) => const Positioned(
            left: 20,
            top: 10,
            child: SizedBox.square(key: lens, dimension: 16),
          ),
        );
        subject.select();
        await subject.pump(
          tester,
          terminalAlignment: Alignment.center,
          magnifierConfiguration: configuration,
        );
        final drag = await subject.startDrag(tester, _Fixture.startHandle);

        await drag.moveBy(const Offset(-8, 0));
        await tester.pump();

        expect(tester.getTopLeft(find.byKey(lens)), const Offset(20, 10));
      });

      testWidgets('paints the magnifier below later stack children', (
        tester,
      ) async {
        final paintOrder = <String>[];
        final repaint = ChangeNotifier();
        addTearDown(repaint.dispose);
        final configuration = TextMagnifierConfiguration(
          magnifierBuilder: (_, _, _) => Positioned(
            left: 24,
            top: 0,
            child: CustomPaint(
              size: const Size.square(16),
              painter: _PaintOrderRecorder('magnifier', paintOrder, repaint),
            ),
          ),
        );
        subject.select();
        await subject.pump(
          tester,
          magnifierConfiguration: configuration,
          foreground: IgnorePointer(
            child: CustomPaint(
              painter: _PaintOrderRecorder('foreground', paintOrder, repaint),
            ),
          ),
        );
        final drag = await subject.startDrag(tester, _Fixture.startHandle);
        await drag.moveBy(const Offset(0, 16));
        await tester.pump();
        paintOrder.clear();

        repaint.notifyListeners();
        await tester.pump();

        expect(paintOrder, ['magnifier', 'foreground']);
      });

      testWidgets('prioritizes lens movement over selection updates', (
        tester,
      ) async {
        final updates = <String>[];
        late ValueListenable<MagnifierInfo> info;
        final configuration = TextMagnifierConfiguration(
          magnifierBuilder: (_, _, value) {
            info = value;
            return const Text('magnifier');
          },
        );
        subject.select();
        await subject.pump(tester, magnifierConfiguration: configuration);
        final drag = await subject.startDrag(tester, _Fixture.startHandle);
        void recordSelection() => updates.add('selection');
        void recordMagnifier() => updates.add('magnifier');
        subject.controller.addListener(recordSelection);
        info.addListener(recordMagnifier);
        addTearDown(() {
          subject.controller.removeListener(recordSelection);
          info.removeListener(recordMagnifier);
        });

        await drag.moveBy(const Offset(-8, 0));

        expect(updates, ['magnifier', 'selection']);
      });

      testWidgets('tracks the configured magnifier lifecycle', (tester) async {
        ValueListenable<MagnifierInfo>? info;
        final configuration = TextMagnifierConfiguration(
          magnifierBuilder: (_, _, value) {
            info = value;
            return const Text('magnifier');
          },
        );
        subject.select();
        await subject.pump(tester, magnifierConfiguration: configuration);
        final drag = await subject.startDrag(tester, _Fixture.startHandle);

        await drag.moveBy(const Offset(-8, 0));
        await tester.pump();
        final initialPosition = info!.value.globalGesturePosition;
        expect(find.text('magnifier'), findsOneWidget);

        await drag.moveBy(const Offset(-8, 0));
        await tester.pump();
        expect(info!.value.globalGesturePosition, isNot(initialPosition));

        await drag.end();
        await tester.pump();
        expect(find.text('magnifier'), findsNothing);
      });
    });

    group('autoscroll', () {
      testWidgets(
        'scrolls down while the end handle stays below the viewport',
        (tester) async {
          subject.addScrollback();
          subject.controller.scrollToTop();
          subject.select();
          await subject.pump(tester);
          final origin = tester.getTopLeft(
            find.byType(TerminalSelectionHandles),
          );
          final drag = await subject.startDrag(tester, _Fixture.endHandle);
          final before = subject.selection.scrollbar.offset;

          await drag.moveTo(origin + const Offset(56, 80));
          await tester.pump(const Duration(milliseconds: 60));

          expect(subject.selection.scrollbar.offset, greaterThan(before));
          await drag.end();
          await tester.pump(const Duration(milliseconds: 250));
        },
      );

      testWidgets(
        'scrolls up while the start handle stays above the viewport',
        (tester) async {
          subject.addScrollback();
          subject.controller.scrollToBottom();
          subject.select();
          await subject.pump(tester);
          final origin = tester.getTopLeft(
            find.byType(TerminalSelectionHandles),
          );
          final drag = await subject.startDrag(tester, _Fixture.startHandle);
          final before = subject.selection.scrollbar.offset;

          await drag.moveTo(origin + const Offset(8, -16));
          await tester.pump(const Duration(milliseconds: 60));

          expect(subject.selection.scrollbar.offset, lessThan(before));
          await drag.end();
          await tester.pump(const Duration(milliseconds: 250));
        },
      );

      testWidgets('replaces stale owners and stops on geometry invalidation', (
        tester,
      ) async {
        var pointerTicks = 0;
        var handleTicks = 0;
        subject.selection.startAutoscroll(
          SelectionAutoscrollPolicy.pointer,
          () => pointerTicks++,
        );
        await tester.pump(const Duration(milliseconds: 60));
        expect(pointerTicks, greaterThan(0));

        subject.selection.startAutoscroll(
          SelectionAutoscrollPolicy.handle,
          () => handleTicks++,
        );
        final pointerTicksAtReplacement = pointerTicks;
        await tester.pump(const Duration(milliseconds: 60));
        expect(pointerTicks, pointerTicksAtReplacement);
        expect(handleTicks, greaterThan(0));

        subject.selection.stopAutoscroll(SelectionAutoscrollPolicy.pointer);
        final handleTicksBeforeGeometry = handleTicks;
        await tester.pump(const Duration(milliseconds: 60));
        expect(handleTicks, greaterThan(handleTicksBeforeGeometry));

        subject.attachment.commitGeometry(
          const SurfaceMeasurement(
            cols: 8,
            rows: 3,
            cellWidth: 9,
            cellHeight: 16,
            paddingLeft: 0,
            paddingRight: 0,
            paddingTop: 0,
            paddingBottom: 0,
            devicePixelRatio: 1,
          ),
        );
        final handleTicksAtGeometryChange = handleTicks;
        await tester.pump(const Duration(milliseconds: 60));
        expect(handleTicks, handleTicksAtGeometryChange);
      });
    });
  });
}

final class _Fixture {
  static const metrics = CellMetrics(
    cellWidth: 8,
    cellHeight: 16,
    baseline: 12,
  );
  static const startHandle = ValueKey(SelectionEndpoint.start);
  static const endHandle = ValueKey(SelectionEndpoint.end);

  late final ViewAttachment attachment;
  final TerminalController controller;

  SelectionInteraction get selection => attachment.selectionInput;

  _Fixture()
    : controller = TerminalController(
        config: const TerminalConfig(cols: 8, rows: 3),
      ) {
    attachment = ViewAttachment(controller)
      ..commitGeometry(
        const SurfaceMeasurement(
          cols: 8,
          rows: 3,
          cellWidth: 8,
          cellHeight: 16,
          paddingLeft: 0,
          paddingRight: 0,
          paddingTop: 0,
          paddingBottom: 0,
          devicePixelRatio: 1,
        ),
      );
  }

  void dispose() {
    attachment.dispose();
    controller.dispose();
  }

  void addScrollback() {
    controller.write(
      Uint8List.fromList(
        '0\r\n1\r\n2\r\n3\r\n4\r\n5\r\n6\r\n7\r\n8\r\n9'.codeUnits,
      ),
    );
  }

  Future<void> pump(
    WidgetTester tester, {
    bool visible = true,
    TargetPlatform platform = TargetPlatform.android,
    TextMagnifierConfiguration? magnifierConfiguration,
    ScrollController? scrollController,
    Widget? foreground,
    Alignment terminalAlignment = Alignment.topLeft,
  }) async {
    final ownsScrollController = scrollController == null;
    scrollController ??= ScrollController();
    if (ownsScrollController) addTearDown(scrollController.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: platform),
        home: Align(
          alignment: terminalAlignment,
          child: SizedBox(
            width: 64,
            height: 48,
            child: Stack(
              children: [
                Scrollable(
                  controller: scrollController,
                  viewportBuilder: (_, offset) => Stack(
                    children: [
                      Viewport(
                        offset: offset,
                        slivers: const [
                          SliverToBoxAdapter(child: SizedBox(height: 256)),
                        ],
                      ),
                      Positioned.fill(
                        child: TerminalSelectionHandles(
                          selection: attachment.selectionInput,
                          readVirtualMods: () => attachment.readVirtualMods(),
                          onViewportRowChanged:
                              attachment.handleViewportRowChanged,
                          metrics: metrics,
                          visible: visible,
                          magnifierConfiguration: magnifierConfiguration,
                          terminalBackground: const Color(0xFF1D1F21),
                        ),
                      ),
                    ],
                  ),
                ),
                if (foreground case final foreground?)
                  Positioned.fill(child: foreground),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  void select({
    Position start = const Position(row: 1, col: 1),
    Position end = const Position(row: 1, col: 6),
  }) {
    controller.selectRange(start: start, end: end, pointTag: PointTag.viewport);
  }

  Future<_TestDrag> startDrag(WidgetTester tester, Key key) async {
    final target = tester.widget<SelectionHandleTarget>(
      find.ancestor(
        of: find.byKey(key),
        matching: find.byType(SelectionHandleTarget),
      ),
    );
    final origin = tester.getTopLeft(find.byType(TerminalSelectionHandles));
    final position = origin + target.layout.anchor;
    final drag = _TestDrag(await tester.startGesture(position));
    addTearDown(drag.dispose);
    return drag;
  }
}

final class _TestDrag {
  final TestGesture _gesture;
  var _active = true;

  _TestDrag(this._gesture);

  Future<void> dispose() async {
    if (!_active) return;
    await _gesture.cancel();
    _active = false;
  }

  Future<void> end() async {
    if (!_active) return;
    await _gesture.up();
    _active = false;
  }

  Future<void> moveBy(Offset offset) => _gesture.moveBy(offset);

  Future<void> moveTo(Offset position) => _gesture.moveTo(position);
}

final class _PaintOrderRecorder extends CustomPainter {
  final String label;
  final List<String> paintOrder;

  _PaintOrderRecorder(this.label, this.paintOrder, Listenable repaint)
    : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) => paintOrder.add(label);

  @override
  bool shouldRepaint(_PaintOrderRecorder oldDelegate) => false;
}

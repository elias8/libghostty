@Tags(['ffi'])
library;

import 'dart:convert';

import 'package:flterm/flterm.dart' as flterm;
import 'package:flterm/src/controller/terminal_controller.dart';
import 'package:flterm/src/links/link_settings.dart';
import 'package:flterm/src/view/terminal_view.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('TerminalView mouse cursor lifecycle', () {
    late TerminalController controller;

    setUp(() => controller = TerminalController());

    tearDown(() => controller.dispose());

    Widget app({bool autofocus = false}) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 80,
            child: TerminalView(
              controller: controller,
              autofocus: autofocus,
              linkSettings: LinkSettings(
                modifier: .none,
                types: const {LinkType.text},
                onActivate: (_) {},
              ),
            ),
          ),
        ),
      );
    }

    MouseCursor activeCursor(WidgetTester tester, int device) {
      return tester.binding.mouseTracker.debugDeviceActiveCursor(device)!;
    }

    void write(String text) {
      controller.write(Uint8List.fromList(utf8.encode(text)));
    }

    group('stationary link hover', () {
      testWidgets('updates the active cursor after content removes a link', (
        tester,
      ) async {
        write('https://example.test');

        await tester.pumpWidget(app());
        await tester.pumpAndSettle();

        const device = 91;
        final pointer = TestPointer(device, PointerDeviceKind.mouse);
        addTearDown(() => tester.sendEventToBinding(pointer.removePointer()));
        const position = Offset(12, 16);
        await tester.sendEventToBinding(
          pointer.addPointer(location: const Offset(-10, -10)),
        );
        await tester.sendEventToBinding(pointer.hover(position));
        await tester.pump();

        expect(activeCursor(tester, pointer.device), SystemMouseCursors.click);

        write('\r\x1b[2Kplain text');
        await tester.pump();

        expect(activeCursor(tester, pointer.device), SystemMouseCursors.text);
      });

      testWidgets('keeps the link cursor above an OSC 22 shape', (
        tester,
      ) async {
        write('\x1b]22;wait\x07https://example.test');

        await tester.pumpWidget(app());
        await tester.pumpAndSettle();

        const device = 93;
        final pointer = TestPointer(device, PointerDeviceKind.mouse);
        addTearDown(() => tester.sendEventToBinding(pointer.removePointer()));
        await tester.sendEventToBinding(
          pointer.addPointer(location: const Offset(-10, -10)),
        );
        await tester.sendEventToBinding(pointer.hover(const Offset(12, 16)));
        await tester.pump();

        expect(controller.mouseShape, flterm.MouseShape.wait);
        expect(activeCursor(tester, pointer.device), SystemMouseCursors.click);
      });
    });

    testWidgets('maps every OSC 22 shape to a Flutter system cursor', (
      tester,
    ) async {
      final cases = <(String, flterm.MouseShape, MouseCursor)>[
        ('default', flterm.MouseShape.default$, SystemMouseCursors.basic),
        (
          'context-menu',
          flterm.MouseShape.contextMenu,
          SystemMouseCursors.contextMenu,
        ),
        ('help', flterm.MouseShape.help, SystemMouseCursors.help),
        ('pointer', flterm.MouseShape.pointer, SystemMouseCursors.click),
        ('progress', flterm.MouseShape.progress, SystemMouseCursors.progress),
        ('wait', flterm.MouseShape.wait, SystemMouseCursors.wait),
        ('cell', flterm.MouseShape.cell, SystemMouseCursors.cell),
        ('crosshair', flterm.MouseShape.crosshair, SystemMouseCursors.precise),
        ('text', flterm.MouseShape.text, SystemMouseCursors.text),
        (
          'vertical-text',
          flterm.MouseShape.verticalText,
          SystemMouseCursors.verticalText,
        ),
        ('alias', flterm.MouseShape.alias, SystemMouseCursors.alias),
        ('copy', flterm.MouseShape.copy, SystemMouseCursors.copy),
        ('move', flterm.MouseShape.move, SystemMouseCursors.move),
        ('no-drop', flterm.MouseShape.noDrop, SystemMouseCursors.noDrop),
        (
          'not-allowed',
          flterm.MouseShape.notAllowed,
          SystemMouseCursors.forbidden,
        ),
        ('grab', flterm.MouseShape.grab, SystemMouseCursors.grab),
        ('grabbing', flterm.MouseShape.grabbing, SystemMouseCursors.grabbing),
        (
          'all-scroll',
          flterm.MouseShape.allScroll,
          SystemMouseCursors.allScroll,
        ),
        (
          'col-resize',
          flterm.MouseShape.colResize,
          SystemMouseCursors.resizeColumn,
        ),
        (
          'row-resize',
          flterm.MouseShape.rowResize,
          SystemMouseCursors.resizeRow,
        ),
        ('n-resize', flterm.MouseShape.nResize, SystemMouseCursors.resizeUp),
        ('e-resize', flterm.MouseShape.eResize, SystemMouseCursors.resizeRight),
        ('s-resize', flterm.MouseShape.sResize, SystemMouseCursors.resizeDown),
        ('w-resize', flterm.MouseShape.wResize, SystemMouseCursors.resizeLeft),
        (
          'ne-resize',
          flterm.MouseShape.neResize,
          SystemMouseCursors.resizeUpRight,
        ),
        (
          'nw-resize',
          flterm.MouseShape.nwResize,
          SystemMouseCursors.resizeUpLeft,
        ),
        (
          'se-resize',
          flterm.MouseShape.seResize,
          SystemMouseCursors.resizeDownRight,
        ),
        (
          'sw-resize',
          flterm.MouseShape.swResize,
          SystemMouseCursors.resizeDownLeft,
        ),
        (
          'ew-resize',
          flterm.MouseShape.ewResize,
          SystemMouseCursors.resizeLeftRight,
        ),
        (
          'ns-resize',
          flterm.MouseShape.nsResize,
          SystemMouseCursors.resizeUpDown,
        ),
        (
          'nesw-resize',
          flterm.MouseShape.neswResize,
          SystemMouseCursors.resizeUpRightDownLeft,
        ),
        (
          'nwse-resize',
          flterm.MouseShape.nwseResize,
          SystemMouseCursors.resizeUpLeftDownRight,
        ),
        ('zoom-in', flterm.MouseShape.zoomIn, SystemMouseCursors.zoomIn),
        ('zoom-out', flterm.MouseShape.zoomOut, SystemMouseCursors.zoomOut),
      ];

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      const device = 94;
      final pointer = TestPointer(device, PointerDeviceKind.mouse);
      addTearDown(() => tester.sendEventToBinding(pointer.removePointer()));
      await tester.sendEventToBinding(
        pointer.addPointer(location: const Offset(-10, -10)),
      );
      await tester.sendEventToBinding(pointer.hover(const Offset(12, 16)));
      await tester.pump();

      for (final (sequence, shape, cursor) in cases) {
        write('\x1b]22;$sequence\x07');
        await tester.pump();

        expect(controller.mouseShape, shape, reason: sequence);
        expect(activeCursor(tester, pointer.device), cursor, reason: sequence);
      }
    });

    testWidgets('uses tracking fallback for text and default after reset', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      const device = 95;
      final pointer = TestPointer(device, PointerDeviceKind.mouse);
      addTearDown(() => tester.sendEventToBinding(pointer.removePointer()));
      await tester.sendEventToBinding(
        pointer.addPointer(location: const Offset(-10, -10)),
      );
      await tester.sendEventToBinding(pointer.hover(const Offset(12, 16)));
      await tester.pump();

      expect(controller.mouseShape, flterm.MouseShape.text);
      expect(activeCursor(tester, pointer.device), SystemMouseCursors.text);

      write('\x1b[?1000h');
      await tester.pump();
      expect(activeCursor(tester, pointer.device), SystemMouseCursors.basic);

      write('\x1b]22;text\x07');
      await tester.pump();
      expect(controller.mouseShape, flterm.MouseShape.text);
      expect(activeCursor(tester, pointer.device), SystemMouseCursors.basic);

      write('\x1b]22;wait\x07');
      await tester.pump();
      expect(activeCursor(tester, pointer.device), SystemMouseCursors.wait);

      write('\x1b]22;default\x07');
      await tester.pump();
      expect(controller.mouseShape, flterm.MouseShape.default$);
      expect(activeCursor(tester, pointer.device), SystemMouseCursors.basic);

      write('\x1b]22;\x07');
      await tester.pump();
      expect(controller.mouseShape, flterm.MouseShape.text);
      expect(activeCursor(tester, pointer.device), SystemMouseCursors.basic);

      write('\x1b[?1000l\x1b]22;\x07');
      await tester.pump();
      expect(controller.mouseShape, flterm.MouseShape.text);
      expect(activeCursor(tester, pointer.device), SystemMouseCursors.text);
    });

    testWidgets('keeps the latest OSC 22 shape hidden until mouse movement', (
      tester,
    ) async {
      await tester.pumpWidget(app(autofocus: true));
      await tester.pumpAndSettle();

      const device = 96;
      final pointer = TestPointer(device, PointerDeviceKind.mouse);
      addTearDown(() => tester.sendEventToBinding(pointer.removePointer()));
      await tester.sendEventToBinding(
        pointer.addPointer(location: const Offset(-10, -10)),
      );
      await tester.sendEventToBinding(pointer.hover(const Offset(300, 60)));
      await tester.pump();

      write('\x1b]22;wait\x07');
      await tester.pump();
      expect(activeCursor(tester, pointer.device), SystemMouseCursors.wait);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pump();
      expect(activeCursor(tester, pointer.device), SystemMouseCursors.none);

      write('\x1b]22;crosshair\x07');
      await tester.pump();
      expect(activeCursor(tester, pointer.device), SystemMouseCursors.none);

      await tester.sendEventToBinding(pointer.hover(const Offset(320, 60)));
      await tester.pump();
      expect(activeCursor(tester, pointer.device), SystemMouseCursors.precise);
    });

    group('mouse auto-hide', () {
      testWidgets('updates the active cursor after terminal input', (
        tester,
      ) async {
        write('\x1b]22;wait\x07https://example.test');
        await tester.pumpWidget(app(autofocus: true));
        await tester.pumpAndSettle();

        const device = 92;
        final pointer = TestPointer(device, PointerDeviceKind.mouse);
        addTearDown(() => tester.sendEventToBinding(pointer.removePointer()));
        const position = Offset(12, 16);
        await tester.sendEventToBinding(
          pointer.addPointer(location: const Offset(-10, -10)),
        );
        await tester.sendEventToBinding(pointer.hover(position));
        await tester.pump();

        expect(activeCursor(tester, pointer.device), SystemMouseCursors.click);

        await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
        await tester.pump();

        expect(activeCursor(tester, pointer.device), SystemMouseCursors.none);
      });
    });
  });
}

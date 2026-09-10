@Tags(['ffi'])
library;

import 'dart:convert';

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
    });

    group('mouse auto-hide', () {
      testWidgets('updates the active cursor after terminal input', (
        tester,
      ) async {
        write('https://example.test');
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

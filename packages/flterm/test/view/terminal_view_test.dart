import 'dart:convert';
import 'dart:io';

import 'package:flterm/src/controller/terminal_controller.dart';
import 'package:flterm/src/foundation.dart';
import 'package:flterm/src/links/link_settings.dart';
import 'package:flterm/src/rendering.dart';
import 'package:flterm/src/view/terminal_scope.dart';
import 'package:flterm/src/view/terminal_scroll_controller.dart';
import 'package:flterm/src/view/terminal_view.dart';
import 'package:flutter/foundation.dart'
    show
        TargetPlatform,
        debugDefaultTargetPlatformOverride,
        defaultTargetPlatform;
import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart'
    as vt
    show ColorScheme, ColorSchemeReportEncode;
import 'package:libghostty/libghostty.dart' hide ColorScheme, KeyEvent;
import 'package:material_ui/material_ui.dart';

extension _SelectionEdges on Selection {
  Position get _startPoint => start.positionIn(.viewport)!;

  Position get _endPoint => end.positionIn(.viewport)!;

  bool get _forward {
    final start = _startPoint;
    final end = _endPoint;
    return start.row != end.row ? start.row < end.row : start.col <= end.col;
  }

  int get endCol => _forward ? _endPoint.col + 1 : _endPoint.col;

  TerminalSelectionShape get mode {
    return rectangle
        ? TerminalSelectionShape.rectangle
        : TerminalSelectionShape.normal;
  }
}

void main() {
  group('TerminalView', () {
    Future<void> sendSelectAllShortcut(WidgetTester tester) async {
      switch (defaultTargetPlatform) {
        case TargetPlatform.macOS || TargetPlatform.iOS:
          await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
          await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
        case TargetPlatform.linux || TargetPlatform.fuchsia:
          await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
          await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
          await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
        case TargetPlatform.windows || TargetPlatform.android:
          await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
          await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      }
      await tester.pump();
    }

    void writeUtf8(TerminalController controller, String text) {
      controller.write(Uint8List.fromList(utf8.encode(text)));
    }

    Terminal terminal(TerminalController controller) {
      return (controller as TerminalControllerImpl).terminal;
    }

    Selection? activeSelection(TerminalController controller) {
      return terminal(controller).selection;
    }

    String decodeOutput(List<Uint8List> output) {
      return utf8.decode(
        Uint8List.fromList(output.expand((chunk) => chunk).toList()),
      );
    }

    ({int height, int width}) physicalSizeReport(List<Uint8List> output) {
      final match = RegExp(
        '\x1b\\[4;(\\d+);(\\d+)t',
      ).firstMatch(decodeOutput(output))!;
      return (
        height: int.parse(match.group(1)!),
        width: int.parse(match.group(2)!),
      );
    }

    Future<void> sendTextInputDeltas(List<Map<String, Object?>> deltas) async {
      final messageBytes = const JSONMessageCodec().encodeMessage({
        'method': 'TextInputClient.updateEditingStateWithDeltas',
        'args': [
          -1,
          {'deltas': deltas},
        ],
      });
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            SystemChannels.textInput.name,
            messageBytes,
            (_) {},
          );
    }

    List<MethodCall> recordTextInputCalls() {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.textInput, (call) async {
            calls.add(call);
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.textInput, null);
      });
      return calls;
    }

    Map<String, Object?> lastTextInputCall(
      List<MethodCall> calls,
      String method,
    ) {
      return calls.lastWhere((call) => call.method == method).arguments!
          as Map<String, Object?>;
    }

    Future<void> withMacOSPlatform(Future<void> Function() body) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await body();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    }

    Future<void> withWindowsPlatform(Future<void> Function() body) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        await body();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    }

    Future<void> releaseControlIfPressed(WidgetTester tester) async {
      if (!HardwareKeyboard.instance.isControlPressed) return;
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    }

    Widget wrapInApp({
      required TerminalController controller,
      FocusNode? focusNode,
      TerminalTheme? theme,
      TerminalScrollController? scrollController,
      bool autofocus = false,
      bool showKeyboard = true,
      MouseAutoHide mouseAutoHide = .onInput,
      TerminalGestureSettings gestureSettings = const TerminalGestureSettings(),
      LinkSettings linkSettings = const LinkSettings(),
      String? semanticsLabel = 'Terminal',
      String? semanticsHint = 'Activate to focus terminal input',
      EdgeInsets padding = EdgeInsets.zero,
      double width = 800,
      double height = 480,
      Uint8List? fontData,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            height: height,
            child: TerminalView(
              controller: controller,
              focusNode: focusNode,
              theme: theme,
              scrollController: scrollController,
              autofocus: autofocus,
              showKeyboard: showKeyboard,
              mouseAutoHide: mouseAutoHide,
              gestureSettings: gestureSettings,
              linkSettings: linkSettings,
              semanticsLabel: semanticsLabel,
              semanticsHint: semanticsHint,
              padding: padding,
              fontData: fontData,
            ),
          ),
        ),
      );
    }

    Widget wrapSplitTerminals({
      required TerminalController controller,
      required TerminalController controller2,
      bool scoped = false,
    }) {
      final terminals = Column(
        children: [
          Expanded(
            child: TerminalView(
              controller: controller,
              padding: EdgeInsets.zero,
            ),
          ),
          Expanded(
            child: TerminalView(
              controller: controller2,
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      );
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 480,
            child: scoped ? TerminalScope(child: terminals) : terminals,
          ),
        ),
      );
    }

    late TerminalController controller;

    setUp(() => controller = TerminalController());

    tearDown(() => controller.dispose());

    void writeNumberedLines(int count) {
      for (var i = 0; i < count; i++) {
        writeUtf8(controller, 'line $i\r\n');
      }
    }

    TerminalRenderer renderer(WidgetTester tester) {
      return tester.widget<TerminalRenderer>(find.byType(TerminalRenderer));
    }

    Future<TerminalScrollController> pumpBlinkingScrollableTerminal(
      WidgetTester tester,
    ) async {
      controller.dispose();
      controller = TerminalController(
        config: const TerminalConfig(cursorBlink: true),
      );
      final scrollController = TerminalScrollController();
      final theme = TerminalTheme.dark().copyWith(
        cursor: const CursorTheme(blinkInterval: Duration(milliseconds: 10)),
      );
      addTearDown(scrollController.dispose);
      await tester.pumpWidget(
        wrapInApp(
          controller: controller,
          theme: theme,
          scrollController: scrollController,
          autofocus: true,
          showKeyboard: false,
          width: 400,
          height: 80,
        ),
      );
      await tester.pump();
      writeNumberedLines(40);
      await tester.pump();
      await tester.pump();
      return scrollController;
    }

    testWidgets('renders with controller', (tester) async {
      await tester.pumpWidget(wrapInApp(controller: controller));
      expect(find.byType(TerminalView), findsOneWidget);
    });

    testWidgets('semantics expose visible non-concealed terminal text', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          wrapInApp(
            controller: controller,
            semanticsLabel: 'Remote shell',
            semanticsHint: 'Focus remote shell input',
          ),
        );
        await tester.pumpAndSettle();
        writeUtf8(controller, 'visible\r\nshow \x1b[8msecret\x1b[0m text');
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();

        final node = tester.getSemantics(find.bySemanticsLabel('Remote shell'));
        final data = node.getSemanticsData();
        expect(data.label, 'Remote shell');
        expect(data.value, contains('visible'));
        expect(data.value, contains('show'));
        expect(data.value, contains('text'));
        expect(data.value, isNot(contains('secret')));
        expect(data.hint, 'Focus remote shell input');
        expect(data.hasAction(SemanticsAction.tap), isTrue);
        expect(data.hasAction(SemanticsAction.focus), isTrue);
        expect(data.flagsCollection.isLiveRegion, isFalse);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('semantics can be delegated to an embedding application', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          wrapInApp(controller: controller, semanticsLabel: null),
        );
        expect(find.bySemanticsLabel('Terminal'), findsNothing);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('creates an isolated atlas pool without explicit scope', (
      tester,
    ) async {
      final controller2 = TerminalController();
      addTearDown(controller2.dispose);

      await tester.pumpWidget(
        wrapSplitTerminals(controller: controller, controller2: controller2),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TerminalRenderer), findsNWidgets(2));
      expect(find.byType(TerminalScope), findsNWidgets(2));
    });

    testWidgets('uses explicit TerminalScope for descendant terminals', (
      tester,
    ) async {
      final controller2 = TerminalController();
      addTearDown(controller2.dispose);

      await tester.pumpWidget(
        wrapSplitTerminals(
          controller: controller,
          controller2: controller2,
          scoped: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TerminalRenderer), findsNWidgets(2));
      expect(find.byType(TerminalScope), findsOneWidget);
    });

    testWidgets('onResize fires with dimensions from layout', (tester) async {
      final cols = <int>[];
      final rows = <int>[];
      controller.onResize = (reportedCols, reportedRows) {
        cols.add(reportedCols);
        rows.add(reportedRows);
      };

      await tester.pumpWidget(wrapInApp(controller: controller));
      await tester.pumpAndSettle();

      expect(cols, isNotEmpty);
      expect(cols.last, greaterThan(0));
      expect(rows.last, greaterThan(0));
    });

    testWidgets('sizes a pinned Kitty placement during first layout', (
      tester,
    ) async {
      final kittyController = TerminalController(
        config: const TerminalConfig(cursorBlink: false),
      );
      addTearDown(kittyController.dispose);
      final fontData = File(
        'test/fixtures/fonts/JetBrainsMono-Regular.ttf',
      ).readAsBytesSync();
      const payload = '/wAA';
      kittyController.write(
        Uint8List.fromList(
          '\x1b_Gf=24,s=1,v=1,a=T,i=1,c=1,r=1;$payload\x1b\\'.codeUnits,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 480,
              child: TerminalView(
                controller: kittyController,
                padding: EdgeInsets.zero,
                fontData: fontData,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final nativeTerminal = terminal(kittyController);
      final placement = KittyGraphics.of(nativeTerminal)!.placements().single;
      final geometry = nativeTerminal.geometry;
      expect(
        (placement.renderInfo.pixelWidth, placement.renderInfo.pixelHeight),
        (geometry.widthPx ~/ geometry.cols, geometry.heightPx ~/ geometry.rows),
      );
    });

    testWidgets('geometry uses the Flutter view device pixel ratio', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final overriddenMediaQuery = MediaQuery.of(
                context,
              ).copyWith(devicePixelRatio: 7);
              return Scaffold(
                body: MediaQuery(
                  data: overriddenMediaQuery,
                  child: SizedBox(
                    width: 800,
                    height: 480,
                    child: TerminalView(controller: controller),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(renderer(tester).devicePixelRatio, tester.view.devicePixelRatio);
    });

    testWidgets('DPR changes recommit physical geometry', (tester) async {
      final output = <Uint8List>[];
      controller.onOutput = output.add;
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(800, 480);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(wrapInApp(controller: controller));
      await tester.pumpAndSettle();
      controller.write(Uint8List.fromList(utf8.encode('\x1b[14t')));
      final initial = physicalSizeReport(output);
      output.clear();

      tester.view
        ..devicePixelRatio = 2
        ..physicalSize = const Size(1600, 960);
      await tester.pumpAndSettle();
      controller.write(Uint8List.fromList(utf8.encode('\x1b[14t')));

      expect(physicalSizeReport(output), (
        height: initial.height * 2,
        width: initial.width * 2,
      ));
    });

    testWidgets('tap to focus', (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      final calls = recordTextInputCalls();
      await tester.pumpWidget(
        wrapInApp(controller: controller, focusNode: focusNode),
      );

      expect(focusNode.hasFocus, isFalse);

      await tester.tap(find.byType(TerminalView));
      await tester.pumpAndSettle();

      expect(focusNode.hasFocus, isTrue);
      expect(
        calls.where((call) => call.method == 'TextInput.show'),
        isNotEmpty,
      );
    });

    testWidgets('alternate screen keeps soft keyboard enabled', (tester) async {
      final calls = recordTextInputCalls();
      await tester.pumpWidget(
        wrapInApp(controller: controller, autofocus: true),
      );
      await tester.pump();

      writeUtf8(controller, '\x1b[?1049h');
      await tester.pump();

      expect(
        calls.where((call) => call.method == 'TextInput.show'),
        isNotEmpty,
      );
    });

    testWidgets('autofocus focuses on mount', (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      await tester.pumpWidget(
        wrapInApp(
          controller: controller,
          focusNode: focusNode,
          autofocus: true,
        ),
      );
      await tester.pump();

      expect(focusNode.hasFocus, isTrue);
    });

    testWidgets('scrolling into scrollback keeps the cursor visible', (
      tester,
    ) async {
      final scrollController = await pumpBlinkingScrollableTerminal(tester);

      scrollController.jumpTo(0);
      await tester.pump();

      expect(terminal(controller).isViewportActive, isFalse);
      expect(renderer(tester).blinkVisible, isTrue);

      await tester.pump(const Duration(milliseconds: 11));
      await tester.pump();

      expect(renderer(tester).blinkVisible, isTrue);
    });

    testWidgets('scrolling to the live viewport restarts cursor blinking', (
      tester,
    ) async {
      final scrollController = await pumpBlinkingScrollableTerminal(tester);

      scrollController.jumpTo(0);
      await tester.pump();
      scrollController.jumpTo(scrollController.position.maxScrollExtent);
      await tester.pump();

      expect(terminal(controller).isViewportActive, isTrue);

      await tester.pump(const Duration(milliseconds: 11));
      await tester.pump();

      expect(renderer(tester).blinkVisible, isFalse);
    });

    testWidgets('semantics follow the visible scrollback viewport', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        final scrollController = await pumpBlinkingScrollableTerminal(tester);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();

        String semanticsValue() => tester
            .getSemantics(find.bySemanticsLabel('Terminal'))
            .getSemanticsData()
            .value;

        expect(semanticsValue(), contains('line 39'));

        scrollController.jumpTo(0);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();
        expect(semanticsValue(), contains('line 0'));
        expect(semanticsValue(), isNot(contains('line 39')));

        scrollController.jumpTo(scrollController.position.maxScrollExtent);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();
        expect(semanticsValue(), contains('line 39'));
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('focus loss stops cursor blinking in the visible phase', (
      tester,
    ) async {
      controller.dispose();
      controller = TerminalController(
        config: const TerminalConfig(cursorBlink: true),
      );
      final focusNode = FocusNode();
      final theme = TerminalTheme.dark().copyWith(
        cursor: const CursorTheme(blinkInterval: Duration(milliseconds: 10)),
      );
      addTearDown(focusNode.dispose);
      await tester.pumpWidget(
        wrapInApp(
          controller: controller,
          focusNode: focusNode,
          theme: theme,
          autofocus: true,
          showKeyboard: false,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 11));
      await tester.pump();
      expect(renderer(tester).blinkVisible, isFalse);

      focusNode.unfocus();
      await tester.pump();
      await tester.pump();

      expect(focusNode.hasFocus, isFalse);
      expect(renderer(tester).focused, isFalse);
      expect(renderer(tester).blinkVisible, isTrue);
    });

    testWidgets('text input produces output via onOutput', (tester) async {
      final output = <Uint8List>[];
      controller.onOutput = output.add;

      await tester.pumpWidget(
        wrapInApp(controller: controller, autofocus: true),
      );
      await tester.pump();

      tester.testTextInput.enterText('a');
      await tester.pump();

      expect(utf8.decode(output.single), 'a');
    });

    testWidgets('text input applies virtual ctrl to single-char commit', (
      tester,
    ) async {
      final output = <Uint8List>[];
      controller.onOutput = output.add;
      controller.toggleMod(const Mods.ctrl());

      await tester.pumpWidget(
        wrapInApp(controller: controller, autofocus: true),
      );
      await tester.pump();

      tester.testTextInput.enterText('c');
      await tester.pump();

      expect(output.single, utf8.encode('\x03'));
      expect(controller.virtualMods, const Mods.none());
    });

    testWidgets('text input applies virtual ctrl to punctuation commit', (
      tester,
    ) async {
      final output = <Uint8List>[];
      controller.onOutput = output.add;
      controller.toggleMod(const Mods.ctrl());

      await tester.pumpWidget(
        wrapInApp(controller: controller, autofocus: true),
      );
      await tester.pump();

      tester.testTextInput.enterText('[');
      await tester.pump();

      expect(output.single, utf8.encode('\x1b[91;5u'));
      expect(controller.virtualMods, const Mods.none());
    });

    testWidgets('text input emits multi-character commit as plain text', (
      tester,
    ) async {
      final output = <Uint8List>[];
      controller.onOutput = output.add;
      controller.toggleMod(const Mods.ctrl());

      await tester.pumpWidget(
        wrapInApp(controller: controller, autofocus: true),
      );
      await tester.pump();

      tester.testTextInput.enterText('hello');
      await tester.pump();

      expect(decodeOutput(output), 'hello');
      expect(controller.virtualMods, const Mods.none());
    });

    testWidgets('text input emits unmapped commit as plain text', (
      tester,
    ) async {
      final output = <Uint8List>[];
      controller.onOutput = output.add;
      controller.toggleMod(const Mods.ctrl());

      await tester.pumpWidget(
        wrapInApp(controller: controller, autofocus: true),
      );
      await tester.pump();

      tester.testTextInput.enterText('\u{1F600}');
      await tester.pump();

      expect(decodeOutput(output), '\u{1F600}');
      expect(controller.virtualMods, const Mods.none());
    });

    testWidgets('text input deletion respects back-arrow key mode', (
      tester,
    ) async {
      final output = <Uint8List>[];
      controller.onOutput = output.add;
      controller.modeSet(const TerminalMode.backArrowKeyMode(), value: true);

      await tester.pumpWidget(
        wrapInApp(controller: controller, autofocus: true),
      );
      await tester.pump();

      await sendTextInputDeltas([
        {
          'oldText': 'x',
          'deltaText': '',
          'deltaStart': 0,
          'deltaEnd': 1,
          'selectionBase': 0,
          'selectionExtent': 0,
          'selectionAffinity': 'TextAffinity.downstream',
          'selectionIsDirectional': false,
          'composingBase': -1,
          'composingExtent': -1,
        },
      ]);
      await tester.pump();

      expect(output.single, utf8.encode('\x08'));
    });

    testWidgets('desktop text input commit after key event produces output', (
      tester,
    ) async {
      await withMacOSPlatform(() async {
        final output = <Uint8List>[];
        controller.onOutput = output.add;

        await tester.pumpWidget(
          wrapInApp(controller: controller, autofocus: true),
        );
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
        tester.testTextInput.enterText('a');
        await tester.pump();

        expect(utf8.decode(output.single), 'a');
      });
    });

    testWidgets('keyboard input remains available to desktop text input', (
      tester,
    ) async {
      await withMacOSPlatform(() async {
        await tester.pumpWidget(
          wrapInApp(controller: controller, autofocus: true),
        );
        await tester.pump();

        final handled = await tester.sendKeyEvent(LogicalKeyboardKey.keyA);

        expect(handled, isFalse);
      });
    });

    testWidgets('desktop printable key respects terminal keyboard protocol', (
      tester,
    ) async {
      await withMacOSPlatform(() async {
        writeUtf8(controller, '\x1b[=31u');
        final output = <Uint8List>[];
        controller.onOutput = output.add;

        await tester.pumpWidget(
          wrapInApp(controller: controller, autofocus: true),
        );
        await tester.pump();

        final handled = await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
        await tester.pump();

        expect(handled, isTrue);
        expect(decodeOutput(output), isNot('a'));
        expect(decodeOutput(output), startsWith('\x1b'));
      });
    });

    testWidgets('shifted printable key emits text in keyboard protocol mode', (
      tester,
    ) async {
      writeUtf8(controller, '\x1b[=1u');
      final output = <Uint8List>[];
      controller.onOutput = output.add;

      await tester.pumpWidget(
        wrapInApp(controller: controller, autofocus: true, showKeyboard: false),
      );
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyEvent(
        LogicalKeyboardKey.semicolon,
        physicalKey: PhysicalKeyboardKey.semicolon,
        character: ':',
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await tester.pump();

      expect(decodeOutput(output), ':');
    });

    testWidgets('AltGr printable input emits committed text once', (
      tester,
    ) async {
      await withWindowsPlatform(() async {
        final output = <Uint8List>[];
        controller.onOutput = output.add;
        await tester.pumpWidget(
          wrapInApp(controller: controller, autofocus: true),
        );
        await tester.pump();

        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.altRight);
        await tester.sendKeyEvent(
          LogicalKeyboardKey.keyQ,
          physicalKey: PhysicalKeyboardKey.keyQ,
          character: '@',
        );
        tester.testTextInput.enterText('@');
        await tester.sendKeyUpEvent(LogicalKeyboardKey.altRight);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();

        expect(decodeOutput(output), '@');
      });
    });

    testWidgets('Kitty keyboard input reports Caps Lock', (tester) async {
      writeUtf8(controller, '\x1b[=31u');
      final output = <Uint8List>[];
      controller.onOutput = output.add;
      await tester.pumpWidget(
        wrapInApp(controller: controller, autofocus: true, showKeyboard: false),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.capsLock);
      output.clear();

      await tester.sendKeyDownEvent(
        LogicalKeyboardKey.keyJ,
        physicalKey: PhysicalKeyboardKey.keyJ,
        character: 'J',
      );
      final encoded = decodeOutput(output);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyJ);
      await tester.sendKeyEvent(LogicalKeyboardKey.capsLock);

      expect(encoded, '\x1b[106;65;74u');
    });

    testWidgets('Kitty keyboard input reports Num Lock', (tester) async {
      writeUtf8(controller, '\x1b[=31u');
      final output = <Uint8List>[];
      controller.onOutput = output.add;
      await tester.pumpWidget(
        wrapInApp(controller: controller, autofocus: true, showKeyboard: false),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.numLock);
      output.clear();

      await tester.sendKeyDownEvent(
        LogicalKeyboardKey.keyJ,
        physicalKey: PhysicalKeyboardKey.keyJ,
        character: 'j',
      );
      final encoded = decodeOutput(output);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyJ);
      await tester.sendKeyEvent(LogicalKeyboardKey.numLock);

      expect(encoded, '\x1b[106;129;106u');
    });

    testWidgets('composition updates preedit without output', (tester) async {
      final output = <Uint8List>[];
      controller.onOutput = output.add;

      await tester.pumpWidget(
        wrapInApp(controller: controller, autofocus: true),
      );
      await tester.pump();

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'ni',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 0, end: 2),
        ),
      );
      await tester.pump();

      expect(
        tester
            .widget<TerminalRenderer>(find.byType(TerminalRenderer))
            .preeditText,
        'ni',
      );
      expect(output, isEmpty);
    });

    testWidgets('composition clears selection when it starts', (tester) async {
      await tester.pumpWidget(
        wrapInApp(controller: controller, autofocus: true),
      );
      await tester.pump();
      controller.selectRange(
        start: const Position(row: 0, col: 0),
        end: const Position(row: 0, col: 4),
      );

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'ni',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 0, end: 2),
        ),
      );
      await tester.pump();

      expect(controller.hasSelection, isFalse);
    });

    testWidgets('composition scrolls to bottom when it starts', (tester) async {
      controller.dispose();
      controller = TerminalController(
        config: const TerminalConfig(cols: 20, rows: 3),
      );

      await tester.pumpWidget(
        wrapInApp(controller: controller, autofocus: true),
      );
      await tester.pump();
      writeNumberedLines(100);
      controller.scrollToTop();

      expect(controller.scrollbar.offset, lessThan(controller.scrollbackRows));

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'ni',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 0, end: 2),
        ),
      );
      await tester.pump();

      expect(controller.scrollbar.offset, controller.scrollbackRows);
    });

    testWidgets('delayed desktop composition emits only committed text', (
      tester,
    ) async {
      await withMacOSPlatform(() async {
        final output = <Uint8List>[];
        controller.onOutput = output.add;

        await tester.pumpWidget(
          wrapInApp(controller: controller, autofocus: true),
        );
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
        await tester.pump(const Duration(milliseconds: 2));
        await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
        await tester.pump(const Duration(milliseconds: 2));
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: 'ni',
            selection: TextSelection.collapsed(offset: 2),
            composing: TextRange(start: 0, end: 2),
          ),
        );
        await tester.pump();
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: '你',
            selection: TextSelection.collapsed(offset: 1),
          ),
        );
        await tester.pump();

        expect(decodeOutput(output), '你');
      });
    });

    testWidgets('composition keeps desktop keyboard input available', (
      tester,
    ) async {
      await withMacOSPlatform(() async {
        final output = <Uint8List>[];
        controller.onOutput = output.add;

        await tester.pumpWidget(
          wrapInApp(controller: controller, autofocus: true),
        );
        await tester.pump();

        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: 'n',
            selection: TextSelection.collapsed(offset: 1),
            composing: TextRange(start: 0, end: 1),
          ),
        );
        await tester.pump();

        final handled = await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
        await tester.pump(const Duration(milliseconds: 1));

        expect(handled, isFalse);
        expect(output, isEmpty);
      });
    });

    testWidgets('finalized composition commits text and clears preedit', (
      tester,
    ) async {
      final output = <Uint8List>[];
      controller.onOutput = output.add;

      await tester.pumpWidget(
        wrapInApp(controller: controller, autofocus: true),
      );
      await tester.pump();

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'ni',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 0, end: 2),
        ),
      );
      await tester.pump();

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '日',
          selection: TextSelection.collapsed(offset: 1),
        ),
      );
      await tester.pump();

      expect(
        tester
            .widget<TerminalRenderer>(find.byType(TerminalRenderer))
            .preeditText,
        isEmpty,
      );
      expect(utf8.decode(output.single), '日');
    });

    testWidgets(
      'desktop backspace with Caps Lock forwards after candidate commit',
      (tester) async {
        await withMacOSPlatform(() async {
          final calls = recordTextInputCalls();
          final output = <Uint8List>[];
          controller.onOutput = output.add;
          controller.modeSet(
            const TerminalMode.backArrowKeyMode(),
            value: true,
          );

          await tester.pumpWidget(
            wrapInApp(controller: controller, autofocus: true),
          );
          await tester.pump();
          tester.testTextInput.updateEditingValue(
            const TextEditingValue(
              text: 'ni',
              selection: TextSelection.collapsed(offset: 2),
              composing: TextRange(start: 0, end: 2),
            ),
          );
          await tester.pump();
          tester.testTextInput.updateEditingValue(
            const TextEditingValue(
              text: '你',
              selection: TextSelection.collapsed(offset: 1),
            ),
          );
          await tester.pump();
          await tester.sendKeyEvent(LogicalKeyboardKey.capsLock);
          calls.clear();
          output.clear();

          final handled = await tester.sendKeyEvent(
            LogicalKeyboardKey.backspace,
          );
          await tester.pump();
          await tester.sendKeyEvent(LogicalKeyboardKey.capsLock);

          expect(handled, isFalse);
          expect(decodeOutput(output), '\x08');
          expect(
            calls.where((call) => call.method == 'TextInput.clearClient'),
            isEmpty,
          );
          expect(
            calls.where((call) => call.method == 'TextInput.hide'),
            isEmpty,
          );

          await sendTextInputDeltas([
            {
              'oldText': '你',
              'deltaText': '',
              'deltaStart': 0,
              'deltaEnd': 1,
              'selectionBase': 0,
              'selectionExtent': 0,
              'selectionAffinity': 'TextAffinity.downstream',
              'selectionIsDirectional': false,
              'composingBase': -1,
              'composingExtent': -1,
            },
          ]);
          await tester.pump();

          expect(decodeOutput(output), '\x08');
        });
      },
    );

    testWidgets(
      'desktop modified backspace after candidate commit stays terminal-only',
      (tester) async {
        await withMacOSPlatform(() async {
          final output = <Uint8List>[];
          controller.onOutput = output.add;
          controller.modeSet(
            const TerminalMode.backArrowKeyMode(),
            value: true,
          );

          await tester.pumpWidget(
            wrapInApp(controller: controller, autofocus: true),
          );
          await tester.pump();
          tester.testTextInput.updateEditingValue(
            const TextEditingValue(
              text: 'ni',
              selection: TextSelection.collapsed(offset: 2),
              composing: TextRange(start: 0, end: 2),
            ),
          );
          await tester.pump();
          tester.testTextInput.updateEditingValue(
            const TextEditingValue(
              text: '你',
              selection: TextSelection.collapsed(offset: 1),
            ),
          );
          await tester.pump();
          output.clear();

          await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
          final handled = await tester.sendKeyEvent(
            LogicalKeyboardKey.backspace,
          );
          await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
          await tester.pump();

          expect(handled, isTrue);
          expect(output, hasLength(1));

          await sendTextInputDeltas([
            {
              'oldText': 'x',
              'deltaText': '',
              'deltaStart': 0,
              'deltaEnd': 1,
              'selectionBase': 0,
              'selectionExtent': 0,
              'selectionAffinity': 'TextAffinity.downstream',
              'selectionIsDirectional': false,
              'composingBase': -1,
              'composingExtent': -1,
            },
          ]);
          await tester.pump();

          expect(output, hasLength(2));
        });
      },
    );

    testWidgets('text input geometry tracks terminal cursor cell', (
      tester,
    ) async {
      final calls = recordTextInputCalls();
      writeUtf8(controller, 'prompt\r\nab');

      await tester.pumpWidget(
        wrapInApp(controller: controller, autofocus: true),
      );
      await tester.pump();
      await tester.pump();

      final renderBox = tester.renderObject<TerminalRenderBox>(
        find.byType(TerminalRenderer),
      );
      final expected = renderBox.textInputCaretRect;
      final editable = lastTextInputCall(
        calls,
        'TextInput.setEditableSizeAndTransform',
      );
      final caret = lastTextInputCall(calls, 'TextInput.setCaretRect');
      final composing = lastTextInputCall(calls, 'TextInput.setMarkedTextRect');

      expect(editable['width'], renderBox.size.width);
      expect(editable['height'], renderBox.size.height);
      expect(caret['x'], expected.left);
      expect(caret['y'], expected.top);
      expect(composing['x'], expected.left);
      expect(composing['y'], expected.top);
      expect(expected.left, greaterThan(0));
      expect(expected.top, greaterThan(0));
    });

    group('unmount', () {
      testWidgets('clears focus state', (tester) async {
        final focusNode = FocusNode();
        addTearDown(focusNode.dispose);
        await tester.pumpWidget(
          wrapInApp(controller: controller, focusNode: focusNode),
        );
        focusNode.requestFocus();
        await tester.pump();

        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        await tester.pumpAndSettle();

        expect(focusNode.hasFocus, isFalse);
      });

      testWidgets('leaves the application-owned controller usable', (
        tester,
      ) async {
        final output = <Uint8List>[];
        controller.onOutput = output.add;
        await tester.pumpWidget(wrapInApp(controller: controller));

        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        controller.sendText('ready');

        expect(decodeOutput(output), 'ready');
      });

      testWidgets('releases the controller view attachment', (tester) async {
        await tester.pumpWidget(wrapInApp(controller: controller));
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));

        await tester.pumpWidget(wrapInApp(controller: controller));

        expect(find.byType(TerminalView), findsOneWidget);
      });
    });

    testWidgets('changing theme updates metrics', (tester) async {
      await tester.pumpWidget(wrapInApp(controller: controller));

      final largeTheme = TerminalTheme(
        palette: ColorPalette(
          ansiColors: List.generate(16, (_) => const Color(0xFF888888)),
          background: const Color(0xFF000000),
          foreground: const Color(0xFFFFFFFF),
        ),
        fontSize: 24.0,
      );

      await tester.pumpWidget(
        wrapInApp(controller: controller, theme: largeTheme),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TerminalView), findsOneWidget);
    });

    testWidgets('changing font data updates metrics', (tester) async {
      final theme = TerminalTheme.dark().copyWith(
        fontFamily: 'Missing Font',
        fontSize: 24,
      );
      final fontData = File(
        'test/fixtures/fonts/JetBrainsMono-Regular.ttf',
      ).readAsBytesSync();
      await tester.pumpWidget(wrapInApp(controller: controller, theme: theme));
      final initialMetrics = renderer(tester).metrics;

      await tester.pumpWidget(
        wrapInApp(controller: controller, theme: theme, fontData: fontData),
      );

      expect(renderer(tester).metrics, isNot(initialMetrics));
    });

    testWidgets('reports light color scheme for perceived-light backgrounds', (
      tester,
    ) async {
      final output = <Uint8List>[];
      controller.onOutput = output.add;
      final theme = TerminalTheme(
        palette: ColorPalette(
          ansiColors: List.filled(16, const Color(0xFF888888)),
          background: const Color(0xFFFF8000),
          foreground: const Color(0xFF000000),
        ),
      );

      await tester.pumpWidget(wrapInApp(controller: controller, theme: theme));
      writeUtf8(controller, '\x1b[?996n');

      expect(decodeOutput(output), vt.ColorScheme.light.encode());
    });

    testWidgets('sendText via controller produces onOutput', (tester) async {
      final output = <Uint8List>[];
      controller.onOutput = output.add;

      await tester.pumpWidget(wrapInApp(controller: controller));
      await tester.pump();

      controller.sendText('hello');

      expect(output, hasLength(1));
      expect(utf8.decode(output.first), 'hello');
    });

    testWidgets('changing controller detaches old and attaches new', (
      tester,
    ) async {
      final controller2 = TerminalController();
      addTearDown(controller2.dispose);

      await tester.pumpWidget(wrapInApp(controller: controller));

      await tester.pumpWidget(wrapInApp(controller: controller2));
      await tester.pumpAndSettle();

      expect(find.byType(TerminalView), findsOneWidget);
    });

    testWidgets('changing controller clears cached terminal semantics', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final controller2 = TerminalController();
      addTearDown(controller2.dispose);
      try {
        writeUtf8(controller, 'old terminal');
        await tester.pumpWidget(wrapInApp(controller: controller));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();

        String semanticsValue() => tester
            .getSemantics(find.bySemanticsLabel('Terminal'))
            .getSemanticsData()
            .value;
        expect(semanticsValue(), contains('old terminal'));

        writeUtf8(controller2, 'new terminal');
        await tester.pumpWidget(wrapInApp(controller: controller2));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();

        expect(semanticsValue(), isNot(contains('old terminal')));
        expect(semanticsValue(), contains('new terminal'));
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('changing controller reports focus loss to the old terminal', (
      tester,
    ) async {
      final controller2 = TerminalController();
      final output = <Uint8List>[];
      controller.onOutput = output.add;
      writeUtf8(controller, '\x1b[?1004h');
      addTearDown(controller2.dispose);
      await tester.pumpWidget(
        wrapInApp(controller: controller, autofocus: true),
      );
      await tester.pump();
      output.clear();

      await tester.pumpWidget(
        wrapInApp(controller: controller2, autofocus: true),
      );

      expect(decodeOutput(output), FocusEvent.lost.encode());
    });

    testWidgets('changing controller reports focus gain to the new terminal', (
      tester,
    ) async {
      final controller2 = TerminalController();
      final output = <Uint8List>[];
      controller2.onOutput = output.add;
      writeUtf8(controller2, '\x1b[?1004h');
      addTearDown(controller2.dispose);
      await tester.pumpWidget(
        wrapInApp(controller: controller, autofocus: true),
      );
      await tester.pump();

      await tester.pumpWidget(
        wrapInApp(controller: controller2, autofocus: true),
      );

      expect(decodeOutput(output), FocusEvent.gained.encode());
    });

    testWidgets('controller and focus node change atomically', (tester) async {
      final calls = recordTextInputCalls();
      final controller2 = TerminalController();
      final firstFocusNode = FocusNode();
      final secondFocusNode = FocusNode();
      addTearDown(controller2.dispose);
      addTearDown(firstFocusNode.dispose);
      addTearDown(secondFocusNode.dispose);

      await tester.pumpWidget(
        wrapInApp(
          controller: controller,
          focusNode: firstFocusNode,
          autofocus: true,
        ),
      );
      await tester.pump();
      calls.clear();

      await tester.pumpWidget(
        wrapInApp(controller: controller2, focusNode: secondFocusNode),
      );
      await tester.pump();

      expect(firstFocusNode.hasFocus, isFalse);
      expect(secondFocusNode.hasFocus, isFalse);
      expect(
        calls.where((call) => call.method == 'TextInput.clearClient'),
        hasLength(1),
      );
      expect(
        calls.where((call) => call.method == 'TextInput.setClient'),
        isEmpty,
      );
    });

    testWidgets('syncs the scroll screen when changing to an alternate TUI', (
      tester,
    ) async {
      final controller2 = TerminalController();
      final scrollController = TerminalScrollController();
      addTearDown(controller2.dispose);
      addTearDown(scrollController.dispose);
      writeUtf8(controller2, '\x1b[?1049h');

      await tester.pumpWidget(
        wrapInApp(controller: controller, scrollController: scrollController),
      );
      await tester.pump();

      await tester.pumpWidget(
        wrapInApp(controller: controller2, scrollController: scrollController),
      );
      await tester.pump();

      expect(scrollController.activeScreen, TerminalScreen.alternate);
    });

    testWidgets('changing scrollController keeps the view mounted', (
      tester,
    ) async {
      final sc1 = TerminalScrollController();
      final sc2 = TerminalScrollController();
      addTearDown(sc1.dispose);
      addTearDown(sc2.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 480,
              child: TerminalView(
                controller: controller,
                scrollController: sc1,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 480,
              child: TerminalView(
                controller: controller,
                scrollController: sc2,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TerminalView), findsOneWidget);
    });

    testWidgets('showKeyboard false skips keyboard show on focus', (
      tester,
    ) async {
      final calls = recordTextInputCalls();
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        wrapInApp(
          controller: controller,
          focusNode: focusNode,
          showKeyboard: false,
        ),
      );

      await tester.tap(find.byType(TerminalView));
      await tester.pumpAndSettle();

      expect(focusNode.hasFocus, isTrue);
      expect(
        calls.where((call) => call.method == 'TextInput.setClient'),
        hasLength(1),
      );
      expect(calls.where((call) => call.method == 'TextInput.show'), isEmpty);
    });

    group('text input connection', () {
      List<MethodCall> lifecycleCalls(List<MethodCall> calls) {
        return calls
            .where(
              (call) => const {
                'TextInput.setClient',
                'TextInput.clearClient',
                'TextInput.show',
                'TextInput.hide',
                'TextInput.updateConfig',
              }.contains(call.method),
            )
            .toList();
      }

      testWidgets('uses the containing Flutter view', (tester) async {
        final calls = recordTextInputCalls();

        await tester.pumpWidget(
          wrapInApp(controller: controller, autofocus: true),
        );
        await tester.pump();
        final setClient = calls.singleWhere(
          (call) => call.method == 'TextInput.setClient',
        );
        final arguments = setClient.arguments! as List<Object?>;
        final configuration = arguments[1]! as Map<String, Object?>;

        expect(configuration['viewId'], tester.view.viewId);
      });

      testWidgets('keeps the connection across same-view dependency changes', (
        tester,
      ) async {
        final calls = recordTextInputCalls();
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          wrapInApp(controller: controller, autofocus: true),
        );
        await tester.pump();
        calls.clear();

        tester.view.devicePixelRatio = tester.view.devicePixelRatio + 1;
        await tester.pump();

        expect(lifecycleCalls(calls), isEmpty);
      });

      testWidgets('closes the connection when the focus node changes', (
        tester,
      ) async {
        final calls = recordTextInputCalls();
        final firstFocusNode = FocusNode();
        final secondFocusNode = FocusNode();
        addTearDown(firstFocusNode.dispose);
        addTearDown(secondFocusNode.dispose);

        await tester.pumpWidget(
          wrapInApp(
            controller: controller,
            focusNode: firstFocusNode,
            autofocus: true,
          ),
        );
        await tester.pump();
        calls.clear();

        await tester.pumpWidget(
          wrapInApp(controller: controller, focusNode: secondFocusNode),
        );
        await tester.pump();

        expect(
          calls.where((call) => call.method == 'TextInput.clearClient'),
          hasLength(1),
        );
        expect(
          calls.where((call) => call.method == 'TextInput.setClient'),
          isEmpty,
        );
      });
    });

    testWidgets('touch drag does not create selection', (tester) async {
      writeUtf8(controller, 'hello world');
      await tester.pumpWidget(
        wrapInApp(controller: controller, autofocus: true),
      );
      await tester.pumpAndSettle();

      final center = tester.getCenter(find.byType(TerminalView));

      final downEvent = PointerDownEvent(position: center);
      await tester.sendEventToBinding(downEvent);
      await tester.pump();

      final moveEvent = PointerMoveEvent(
        position: center + const Offset(100, 0),
        pointer: downEvent.pointer,
      );
      await tester.sendEventToBinding(moveEvent);
      await tester.pump();

      final upEvent = PointerUpEvent(
        position: center + const Offset(100, 0),
        pointer: downEvent.pointer,
      );
      await tester.sendEventToBinding(upEvent);
      await tester.pumpAndSettle();

      expect(controller.hasSelection, isFalse);
    });

    group('link interaction', () {
      testWidgets('mouse tap ignores link without modifier', (tester) async {
        final links = <ActivatedLink>[];
        writeUtf8(controller, 'https://example.test');

        await tester.pumpWidget(
          wrapInApp(
            controller: controller,
            linkSettings: LinkSettings(
              modifier: .control,
              types: const {LinkType.text},
              onActivate: links.add,
            ),
            width: 400,
            height: 80,
          ),
        );
        await tester.pumpAndSettle();

        final topLeft = tester.getTopLeft(find.byType(TerminalView));
        final gesture = await tester.startGesture(
          topLeft + const Offset(4, 8),
          kind: PointerDeviceKind.mouse,
        );
        await gesture.up();
        await tester.pump();

        expect(links, isEmpty);
      });

      testWidgets('mouse tap activates link with modifier', (tester) async {
        final links = <ActivatedLink>[];
        writeUtf8(controller, 'https://example.test');

        await tester.pumpWidget(
          wrapInApp(
            controller: controller,
            autofocus: true,
            linkSettings: LinkSettings(
              modifier: .control,
              types: const {LinkType.text},
              onActivate: links.add,
            ),
            width: 400,
            height: 80,
          ),
        );
        await tester.pumpAndSettle();

        final topLeft = tester.getTopLeft(find.byType(TerminalView));
        addTearDown(() => releaseControlIfPressed(tester));
        await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
        final gesture = await tester.startGesture(
          topLeft + const Offset(4, 8),
          kind: PointerDeviceKind.mouse,
        );
        await gesture.up();
        await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
        await tester.pump();

        expect(links, [
          isA<ActivatedLink>().having(
            (link) => link.text,
            'text',
            'https://example.test',
          ),
        ]);
      });

      testWidgets('modifier hover highlights link', (tester) async {
        writeUtf8(controller, 'https://example.test');

        await tester.pumpWidget(
          wrapInApp(
            controller: controller,
            autofocus: true,
            linkSettings: LinkSettings(
              modifier: .control,
              types: const {LinkType.text},
              onActivate: (_) {},
            ),
            width: 400,
            height: 80,
          ),
        );
        await tester.pumpAndSettle();

        final topLeft = tester.getTopLeft(find.byType(TerminalView));
        addTearDown(() => releaseControlIfPressed(tester));
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        addTearDown(gesture.removePointer);
        await gesture.addPointer(location: topLeft + const Offset(4, 8));
        await gesture.moveTo(topLeft + const Offset(4, 8));
        await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
        await tester.pump();

        expect(
          renderer(tester).linkSnapshot.highlighted,
          const CellRange(
            start: Position(row: 0, col: 0),
            end: Position(row: 0, col: 19),
          ),
        );
      });

      testWidgets('touch tap activates link without modifier', (tester) async {
        final links = <ActivatedLink>[];
        writeUtf8(controller, 'https://example.test');

        await tester.pumpWidget(
          wrapInApp(
            controller: controller,
            linkSettings: LinkSettings(
              types: const {LinkType.text},
              onActivate: links.add,
            ),
            width: 400,
            height: 80,
          ),
        );
        await tester.pumpAndSettle();

        final topLeft = tester.getTopLeft(find.byType(TerminalView));
        await tester.tapAt(topLeft + const Offset(4, 8));
        await tester.pump();

        expect(links, [
          isA<ActivatedLink>().having(
            (link) => link.text,
            'text',
            'https://example.test',
          ),
        ]);
      });
    });

    testWidgets('long press starts normal selection by default', (
      tester,
    ) async {
      writeUtf8(controller, 'hello world');
      await tester.pumpWidget(
        wrapInApp(controller: controller, autofocus: true),
      );
      await tester.pumpAndSettle();

      final center = tester.getCenter(find.byType(TerminalView));
      final gesture = await tester.startGesture(center);
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveBy(const Offset(80, 40));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      final sel = activeSelection(controller);
      expect(sel, isNotNull);
      expect(sel!.mode, TerminalSelectionShape.normal);
    });

    group('scrolling', () {
      Future<
        ({
          TerminalScrollController scrollController,
          Terminal terminal,
          double cellHeight,
        })
      >
      pumpScrollableTerminal(WidgetTester tester) async {
        final scrollController = TerminalScrollController();
        addTearDown(scrollController.dispose);

        await tester.pumpWidget(
          wrapInApp(
            controller: controller,
            scrollController: scrollController,
            showKeyboard: false,
            width: 400,
            height: 80,
          ),
        );
        await tester.pump();
        writeNumberedLines(80);
        await tester.pump();
        await tester.pump();

        return (
          scrollController: scrollController,
          terminal: terminal(controller),
          cellHeight: renderer(tester).metrics.cellHeight,
        );
      }

      List<int> sgrMouseCodes(List<Uint8List> output) {
        return RegExp('\x1b\\[<(\\d+);')
            .allMatches(decodeOutput(output))
            .map((match) => int.parse(match.group(1)!))
            .toList();
      }

      List<int> sgrMouseCodesAfter(List<Uint8List> output, int index) {
        return sgrMouseCodes(output.sublist(index));
      }

      List<({int x, int y})> sgrMousePositions(List<Uint8List> output) {
        return RegExp('\x1b\\[<\\d+;(\\d+);(\\d+)[Mm]')
            .allMatches(decodeOutput(output))
            .map(
              (match) => (
                x: int.parse(match.group(1)!),
                y: int.parse(match.group(2)!),
              ),
            )
            .toList();
      }

      testWidgets('initializes an alternate-screen scroll position', (
        tester,
      ) async {
        writeUtf8(controller, '\x1b[?1049h');
        final scrollController = TerminalScrollController();
        addTearDown(scrollController.dispose);

        await tester.pumpWidget(
          wrapInApp(
            controller: controller,
            scrollController: scrollController,
            showKeyboard: false,
          ),
        );
        await tester.pump();

        final position = scrollController.position;
        expect(
          (position as ScrollbackPosition).activeScreen,
          TerminalScreen.alternate,
        );
        expect(position.minScrollExtent, double.negativeInfinity);
        expect(position.maxScrollExtent, double.infinity);
      });

      testWidgets('restores primary scroll state after alternate screen', (
        tester,
      ) async {
        final fixture = await pumpScrollableTerminal(tester);
        fixture.scrollController.jumpTo(0);
        await tester.pump();
        final primaryPixels = fixture.scrollController.position.pixels;

        writeUtf8(controller, '\x1b[?1049h');
        await tester.pump();
        writeUtf8(controller, '\x1b[?1049l');
        await tester.pump();
        await tester.pump();

        expect(
          fixture.scrollController.position.pixels,
          closeTo(primaryPixels, 0.01),
        );
      });

      Future<void> sendHorizontalTrackpadFling(
        WidgetTester tester,
        TestPointer pointer,
        Offset position,
        Duration startTime,
        ({double first, double second, double third}) pan,
      ) async {
        await tester.sendEventToBinding(
          pointer.panZoomStart(position, timeStamp: startTime),
        );
        await tester.pump();
        await tester.sendEventToBinding(
          pointer.panZoomUpdate(
            position,
            pan: Offset(pan.first, 0),
            timeStamp: startTime + const Duration(milliseconds: 8),
          ),
        );
        await tester.sendEventToBinding(
          pointer.panZoomUpdate(
            position,
            pan: Offset(pan.second, 0),
            timeStamp: startTime + const Duration(milliseconds: 16),
          ),
        );
        await tester.sendEventToBinding(
          pointer.panZoomUpdate(
            position,
            pan: Offset(pan.third, 0),
            timeStamp: startTime + const Duration(milliseconds: 24),
          ),
        );
        await tester.sendEventToBinding(
          pointer.panZoomEnd(
            timeStamp: startTime + const Duration(milliseconds: 25),
          ),
        );
        await tester.pump();
      }

      Future<void> sendPausedHorizontalTrackpadFling(
        WidgetTester tester,
        TestPointer pointer,
        Offset position,
        Duration startTime,
      ) async {
        await tester.sendEventToBinding(
          pointer.panZoomStart(position, timeStamp: startTime),
        );
        await tester.pump();
        await tester.sendEventToBinding(
          pointer.panZoomUpdate(
            position,
            pan: const Offset(100, 0),
            timeStamp: startTime + const Duration(milliseconds: 8),
          ),
        );
        await tester.sendEventToBinding(
          pointer.panZoomUpdate(
            position,
            pan: const Offset(100, 0),
            timeStamp: startTime + const Duration(milliseconds: 33),
          ),
        );
        await tester.sendEventToBinding(
          pointer.panZoomUpdate(
            position,
            pan: const Offset(200, 0),
            timeStamp: startTime + const Duration(milliseconds: 41),
          ),
        );
        await tester.sendEventToBinding(
          pointer.panZoomUpdate(
            position,
            pan: const Offset(300, 0),
            timeStamp: startTime + const Duration(milliseconds: 49),
          ),
        );
        await tester.sendEventToBinding(
          pointer.panZoomEnd(
            timeStamp: startTime + const Duration(milliseconds: 50),
          ),
        );
        await tester.pump();
      }

      testWidgets('scroll event changes scroll offset', (tester) async {
        final fixture = await pumpScrollableTerminal(tester);
        final initialPixels = fixture.scrollController.position.pixels;
        final center = tester.getCenter(find.byType(TerminalView));

        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: center,
            scrollDelta: const Offset(0, -100),
          ),
        );
        await tester.pumpAndSettle();

        expect(fixture.scrollController.position.pixels, isNot(initialPixels));
      });

      testWidgets('tracked scroll claims the signal before local scrolling', (
        tester,
      ) async {
        final fixture = await pumpScrollableTerminal(tester);
        final initialPixels = fixture.scrollController.position.pixels;
        writeUtf8(controller, '\x1b[?1003h\x1b[?1006h');
        await tester.pump();

        final output = <Uint8List>[];
        controller.onOutput = output.add;
        final center = tester.getCenter(find.byType(TerminalView));
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: center,
            scrollDelta: const Offset(0, -100),
          ),
        );
        await tester.pumpAndSettle();

        expect(decodeOutput(output), contains('\x1b[<64;'));
        expect(fixture.scrollController.position.pixels, initialPixels);
      });

      testWidgets('tracked trackpad pan claims the gesture before scrolling', (
        tester,
      ) async {
        final fixture = await pumpScrollableTerminal(tester);
        final initialPixels = fixture.scrollController.position.pixels;
        writeUtf8(controller, '\x1b[?1003h\x1b[?1006h');
        await tester.pump();

        final output = <Uint8List>[];
        controller.onOutput = output.add;
        final pointer = TestPointer(100, PointerDeviceKind.trackpad);
        final center = tester.getCenter(find.byType(TerminalView));
        await tester.sendEventToBinding(pointer.panZoomStart(center));
        await tester.pump();
        await tester.sendEventToBinding(
          pointer.panZoomUpdate(center, pan: const Offset(0, 100)),
        );
        await tester.pumpAndSettle();
        await tester.sendEventToBinding(pointer.panZoomEnd());
        await tester.pump();

        expect(decodeOutput(output), contains('\x1b[<64;'));
        expect(fixture.scrollController.position.pixels, initialPixels);
      });

      testWidgets('trackpad fling continues with terminal momentum', (
        tester,
      ) async {
        await pumpScrollableTerminal(tester);
        writeUtf8(controller, '\x1b[?1049h\x1b[?1003h\x1b[?1006h');
        await tester.pump();

        final output = <Uint8List>[];
        controller.onOutput = output.add;
        final center = tester.getCenter(find.byType(TerminalView));
        final pointer = TestPointer(104, PointerDeviceKind.trackpad);
        await tester.sendEventToBinding(pointer.panZoomStart(center));
        await tester.pump();
        await tester.sendEventToBinding(
          pointer.panZoomUpdate(
            center,
            pan: const Offset(0, 30),
            timeStamp: const Duration(milliseconds: 8),
          ),
        );
        await tester.sendEventToBinding(
          pointer.panZoomUpdate(
            center,
            pan: const Offset(0, 60),
            timeStamp: const Duration(milliseconds: 16),
          ),
        );
        await tester.sendEventToBinding(
          pointer.panZoomUpdate(
            center,
            pan: const Offset(0, 100),
            timeStamp: const Duration(milliseconds: 24),
          ),
        );
        await tester.pump();
        final initialReportCount = sgrMouseCodes(output).length;
        await tester.sendEventToBinding(
          pointer.panZoomEnd(timeStamp: const Duration(milliseconds: 25)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(sgrMouseCodes(output).length, greaterThan(initialReportCount));
      });

      testWidgets('wheel input interrupts vertical momentum immediately', (
        tester,
      ) async {
        await pumpScrollableTerminal(tester);
        writeUtf8(controller, '\x1b[?1049h\x1b[?1003h\x1b[?1006h');
        await tester.pump();

        final output = <Uint8List>[];
        controller.onOutput = output.add;
        final center = tester.getCenter(find.byType(TerminalView));
        final pointer = TestPointer(115, PointerDeviceKind.trackpad);
        await tester.sendEventToBinding(pointer.panZoomStart(center));
        await tester.pump();
        await tester.sendEventToBinding(
          pointer.panZoomUpdate(
            center,
            pan: const Offset(0, 30),
            timeStamp: const Duration(milliseconds: 8),
          ),
        );
        await tester.sendEventToBinding(
          pointer.panZoomUpdate(
            center,
            pan: const Offset(0, 60),
            timeStamp: const Duration(milliseconds: 16),
          ),
        );
        await tester.sendEventToBinding(
          pointer.panZoomUpdate(
            center,
            pan: const Offset(0, 100),
            timeStamp: const Duration(milliseconds: 24),
          ),
        );
        await tester.sendEventToBinding(
          pointer.panZoomEnd(timeStamp: const Duration(milliseconds: 25)),
        );
        await tester.pump(const Duration(milliseconds: 32));
        output.clear();

        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: center,
            scrollDelta: const Offset(0, 160),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          sgrMouseCodes(output),
          allOf(isNotEmpty, everyElement(equals(65))),
        );
      });

      testWidgets('repeated horizontal flings carry active momentum', (
        tester,
      ) async {
        await withMacOSPlatform(() async {
          await pumpScrollableTerminal(tester);
          writeUtf8(controller, '\x1b[?1049h\x1b[?1003h\x1b[?1006h');
          await tester.pump();

          final output = <Uint8List>[];
          controller.onOutput = output.add;
          final center = tester.getCenter(find.byType(TerminalView));
          final singlePointer = TestPointer(108, PointerDeviceKind.trackpad);
          await sendHorizontalTrackpadFling(
            tester,
            singlePointer,
            center,
            Duration.zero,
            (first: 100, second: 200, third: 300),
          );
          output.clear();
          await tester.pump(const Duration(milliseconds: 100));
          final singleFlingReportCount = sgrMouseCodes(output).length;
          await tester.sendEventToBinding(
            singlePointer.scrollInertiaCancel(
              timeStamp: const Duration(milliseconds: 150),
            ),
          );
          await tester.pump();

          await sendHorizontalTrackpadFling(
            tester,
            TestPointer(109, PointerDeviceKind.trackpad),
            center,
            const Duration(milliseconds: 200),
            (first: 30, second: 60, third: 100),
          );
          await tester.pump(const Duration(milliseconds: 32));
          await sendHorizontalTrackpadFling(
            tester,
            TestPointer(110, PointerDeviceKind.trackpad),
            center,
            const Duration(milliseconds: 257),
            (first: 100, second: 200, third: 300),
          );
          output.clear();
          await tester.pump(const Duration(milliseconds: 100));

          expect(
            sgrMouseCodes(output).length,
            greaterThan(singleFlingReportCount + 1),
          );
        });
      });

      testWidgets('stationary pan drops carried horizontal momentum', (
        tester,
      ) async {
        await withMacOSPlatform(() async {
          await pumpScrollableTerminal(tester);
          writeUtf8(controller, '\x1b[?1049h\x1b[?1003h\x1b[?1006h');
          await tester.pump();

          final output = <Uint8List>[];
          controller.onOutput = output.add;
          final center = tester.getCenter(find.byType(TerminalView));
          final singlePointer = TestPointer(112, PointerDeviceKind.trackpad);
          await sendHorizontalTrackpadFling(
            tester,
            singlePointer,
            center,
            Duration.zero,
            (first: 100, second: 200, third: 300),
          );
          output.clear();
          await tester.pump(const Duration(milliseconds: 100));
          final singleFlingReportCount = sgrMouseCodes(output).length;
          await tester.sendEventToBinding(
            singlePointer.scrollInertiaCancel(
              timeStamp: const Duration(milliseconds: 150),
            ),
          );
          await tester.pump();

          await sendHorizontalTrackpadFling(
            tester,
            TestPointer(113, PointerDeviceKind.trackpad),
            center,
            const Duration(milliseconds: 200),
            (first: 30, second: 60, third: 100),
          );
          await tester.pump(const Duration(milliseconds: 32));
          await sendPausedHorizontalTrackpadFling(
            tester,
            TestPointer(114, PointerDeviceKind.trackpad),
            center,
            const Duration(milliseconds: 257),
          );
          output.clear();
          await tester.pump(const Duration(milliseconds: 100));

          expect(
            sgrMouseCodes(output).length,
            lessThanOrEqualTo(singleFlingReportCount + 1),
          );
        });
      });

      testWidgets('restarts after terminal modes change during inertia', (
        tester,
      ) async {
        await withMacOSPlatform(() async {
          await pumpScrollableTerminal(tester);
          writeUtf8(controller, '\x1b[?1049h\x1b[?1003h\x1b[?1006h');
          await tester.pump();

          final output = <Uint8List>[];
          controller.onOutput = output.add;
          final center = tester.getCenter(find.byType(TerminalView));
          await sendHorizontalTrackpadFling(
            tester,
            TestPointer(119, PointerDeviceKind.trackpad),
            center,
            Duration.zero,
            (first: 100, second: 200, third: 300),
          );
          await tester.pump(const Duration(milliseconds: 32));

          writeUtf8(controller, '\x1b[?1003l\x1b[?1006l\x1b[?1049l');
          await tester.pump();
          writeUtf8(controller, '\x1b[?1049h\x1b[?1003h\x1b[?1006h');
          await tester.pump();
          output.clear();

          await sendHorizontalTrackpadFling(
            tester,
            TestPointer(120, PointerDeviceKind.trackpad),
            center,
            const Duration(milliseconds: 100),
            (first: 100, second: 200, third: 300),
          );
          await tester.pump(const Duration(milliseconds: 100));

          expect(
            sgrMouseCodes(output),
            allOf(isNotEmpty, everyElement(equals(66))),
          );
        });
      });

      testWidgets('touch drag emits alternate-scroll key input', (
        tester,
      ) async {
        await pumpScrollableTerminal(tester);
        writeUtf8(controller, '\x1b[?1049h');
        await tester.pump();

        final output = <Uint8List>[];
        controller.onOutput = output.add;
        final center = tester.getCenter(find.byType(TerminalView));
        final gesture = await tester.startGesture(center);
        await gesture.moveBy(const Offset(0, -300));
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();

        expect(decodeOutput(output), contains('\x1b[B'));
      });

      testWidgets('fast touch scrolling keeps one vertical direction', (
        tester,
      ) async {
        await pumpScrollableTerminal(tester);
        writeUtf8(controller, '\x1b[?1049h\x1b[?1003h\x1b[?1006h');
        await tester.pump();

        final output = <Uint8List>[];
        controller.onOutput = output.add;
        final center = tester.getCenter(find.byType(TerminalView));
        final gesture = await tester.startGesture(center);
        await gesture.moveBy(const Offset(0, -60));
        await gesture.moveBy(const Offset(0, -60));
        await gesture.moveBy(const Offset(0, -60));
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();

        final codes = sgrMouseCodes(output);
        expect(codes, allOf(isNotEmpty, everyElement(equals(65))));
      });

      testWidgets('touch scroll stays at its sequence start position', (
        tester,
      ) async {
        await pumpScrollableTerminal(tester);
        writeUtf8(controller, '\x1b[?1049h\x1b[?1003h\x1b[?1006h');
        await tester.pump();

        final output = <Uint8List>[];
        controller.onOutput = output.add;
        final terminalView = find.byType(TerminalView);
        final center = tester.getCenter(terminalView);
        final localStart = center - tester.getTopLeft(terminalView);
        final startCell = renderer(tester).metrics.cellAt(localStart);
        final gesture = await tester.startGesture(center);
        await gesture.moveBy(const Offset(-60, -10));
        await gesture.moveBy(const Offset(-60, -10));
        await gesture.moveBy(const Offset(-60, -10));
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();

        final positions = sgrMousePositions(output);
        expect(
          positions,
          allOf(
            isNotEmpty,
            everyElement(equals((x: startCell.col + 1, y: startCell.row + 1))),
          ),
        );
      });

      testWidgets('touch scrolling clears the active selection', (
        tester,
      ) async {
        await pumpScrollableTerminal(tester);
        writeUtf8(controller, '\x1b[?1049h');
        controller.selectAll();
        await tester.pump();

        final center = tester.getCenter(find.byType(TerminalView));
        final gesture = await tester.startGesture(center);
        await gesture.moveBy(const Offset(0, -100));
        await tester.pump();
        final selectionCleared = !controller.hasSelection;
        await gesture.up();
        await tester.pump();

        expect(selectionCleared, isTrue);
      });

      testWidgets('alternate wheel scrolling clears the active selection', (
        tester,
      ) async {
        await pumpScrollableTerminal(tester);
        writeUtf8(controller, '\x1b[?1049h');
        controller.selectAll();
        await tester.pump();

        final center = tester.getCenter(find.byType(TerminalView));
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: center,
            scrollDelta: const Offset(0, -16),
          ),
        );
        await tester.pump();

        expect(controller.hasSelection, isFalse);
      });

      testWidgets('touch horizontal scroll emits right-wheel reports', (
        tester,
      ) async {
        await pumpScrollableTerminal(tester);
        writeUtf8(controller, '\x1b[?1049h\x1b[?1003h\x1b[?1006h');
        await tester.pump();

        final output = <Uint8List>[];
        controller.onOutput = output.add;
        final center = tester.getCenter(find.byType(TerminalView));
        final gesture = await tester.startGesture(center);
        await gesture.moveBy(const Offset(-100, 0));
        await tester.pump();
        await gesture.up();
        await tester.pump();

        expect(decodeOutput(output), contains('\x1b[<67;'));
      });

      testWidgets('touch horizontal momentum keeps the fling direction', (
        tester,
      ) async {
        await pumpScrollableTerminal(tester);
        writeUtf8(controller, '\x1b[?1049h\x1b[?1003h\x1b[?1006h');
        await tester.pump();

        final output = <Uint8List>[];
        controller.onOutput = output.add;
        final center = tester.getCenter(find.byType(TerminalView));
        final pointer = TestPointer(107);
        await tester.sendEventToBinding(pointer.down(center));
        await tester.sendEventToBinding(
          pointer.move(
            center.translate(-30, 0),
            timeStamp: const Duration(milliseconds: 8),
          ),
        );
        await tester.sendEventToBinding(
          pointer.move(
            center.translate(-60, 0),
            timeStamp: const Duration(milliseconds: 16),
          ),
        );
        await tester.sendEventToBinding(
          pointer.move(
            center.translate(-100, 0),
            timeStamp: const Duration(milliseconds: 24),
          ),
        );
        await tester.pump();
        final dragEventCount = output.length;
        await tester.sendEventToBinding(
          pointer.up(timeStamp: const Duration(milliseconds: 25)),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final momentumCodes = sgrMouseCodesAfter(output, dragEventCount);
        expect(momentumCodes, allOf(isNotEmpty, everyElement(equals(67))));
      });

      testWidgets('touch scrolling focuses the touched split terminal', (
        tester,
      ) async {
        final controller2 = TerminalController();
        final focusNode = FocusNode();
        final focusNode2 = FocusNode();
        addTearDown(controller2.dispose);
        addTearDown(focusNode.dispose);
        addTearDown(focusNode2.dispose);
        writeUtf8(controller, '\x1b[?1049h\x1b[?1003h\x1b[?1006h');
        writeUtf8(controller2, '\x1b[?1049h\x1b[?1003h\x1b[?1006h');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 480,
                child: Column(
                  children: [
                    Expanded(
                      child: TerminalView(
                        controller: controller,
                        focusNode: focusNode,
                        autofocus: true,
                      ),
                    ),
                    Expanded(
                      child: TerminalView(
                        controller: controller2,
                        focusNode: focusNode2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final bottom = find.byType(TerminalView).last;
        final gesture = await tester.startGesture(tester.getCenter(bottom));
        await gesture.moveBy(const Offset(0, -100));
        await tester.pump();
        await gesture.up();
        await tester.pump();

        expect(focusNode.hasFocus, isFalse);
        expect(focusNode2.hasFocus, isTrue);
      });

      testWidgets('touch sequence remains owned by its starting split', (
        tester,
      ) async {
        final controller2 = TerminalController();
        addTearDown(controller2.dispose);
        writeUtf8(controller, '\x1b[?1049h\x1b[?1003h\x1b[?1006h');
        writeUtf8(controller2, '\x1b[?1049h\x1b[?1003h\x1b[?1006h');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 480,
                child: Row(
                  children: [
                    Expanded(child: TerminalView(controller: controller)),
                    Expanded(child: TerminalView(controller: controller2)),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final firstOutput = <Uint8List>[];
        final secondOutput = <Uint8List>[];
        controller.onOutput = firstOutput.add;
        controller2.onOutput = secondOutput.add;
        final terminals = find.byType(TerminalView);
        final start = tester.getCenter(terminals.first);
        final other = tester.getCenter(terminals.last);
        final pointer = TestPointer(116);

        await tester.sendEventToBinding(pointer.down(start));
        await tester.sendEventToBinding(
          pointer.move(
            start.translate(0, -100),
            timeStamp: const Duration(milliseconds: 16),
          ),
        );
        await tester.sendEventToBinding(
          pointer.move(
            other.translate(0, -100),
            timeStamp: const Duration(milliseconds: 32),
          ),
        );
        await tester.pump();
        final routing = (
          startReceived: firstOutput.isNotEmpty,
          otherReceived: secondOutput.isNotEmpty,
        );
        await tester.sendEventToBinding(
          pointer.up(timeStamp: const Duration(milliseconds: 48)),
        );

        expect(routing, (startReceived: true, otherReceived: false));
      });

      testWidgets('touch drag starts while prior momentum is active', (
        tester,
      ) async {
        await pumpScrollableTerminal(tester);
        writeUtf8(controller, '\x1b[?1049h');
        await tester.pump();

        final output = <Uint8List>[];
        controller.onOutput = output.add;
        final center = tester.getCenter(find.byType(TerminalView));
        final firstPointer = TestPointer(105);
        await tester.sendEventToBinding(firstPointer.down(center));
        await tester.sendEventToBinding(
          firstPointer.move(
            center.translate(0, -100),
            timeStamp: const Duration(milliseconds: 8),
          ),
        );
        await tester.sendEventToBinding(
          firstPointer.move(
            center.translate(0, -200),
            timeStamp: const Duration(milliseconds: 16),
          ),
        );
        await tester.sendEventToBinding(
          firstPointer.move(
            center.translate(0, -300),
            timeStamp: const Duration(milliseconds: 24),
          ),
        );
        await tester.sendEventToBinding(
          firstPointer.up(timeStamp: const Duration(milliseconds: 25)),
        );
        await tester.pump(const Duration(milliseconds: 32));
        final secondPointer = TestPointer(106);
        await tester.sendEventToBinding(
          secondPointer.down(
            center,
            timeStamp: const Duration(milliseconds: 57),
          ),
        );
        output.clear();
        await tester.sendEventToBinding(
          secondPointer.move(
            center.translate(0, -100),
            timeStamp: const Duration(milliseconds: 73),
          ),
        );
        await tester.pump();
        final restarted = output.isNotEmpty;
        await tester.sendEventToBinding(
          secondPointer.up(timeStamp: const Duration(milliseconds: 89)),
        );

        expect(restarted, isTrue);
      });

      testWidgets('touch contact immediately holds active momentum', (
        tester,
      ) async {
        await pumpScrollableTerminal(tester);
        writeUtf8(controller, '\x1b[?1049h');
        await tester.pump();

        final output = <Uint8List>[];
        controller.onOutput = output.add;
        final center = tester.getCenter(find.byType(TerminalView));
        final firstPointer = TestPointer(117);
        await tester.sendEventToBinding(firstPointer.down(center));
        await tester.sendEventToBinding(
          firstPointer.move(
            center.translate(0, -100),
            timeStamp: const Duration(milliseconds: 8),
          ),
        );
        await tester.sendEventToBinding(
          firstPointer.move(
            center.translate(0, -200),
            timeStamp: const Duration(milliseconds: 16),
          ),
        );
        await tester.sendEventToBinding(
          firstPointer.move(
            center.translate(0, -300),
            timeStamp: const Duration(milliseconds: 24),
          ),
        );
        await tester.sendEventToBinding(
          firstPointer.up(timeStamp: const Duration(milliseconds: 25)),
        );
        await tester.pump(const Duration(milliseconds: 32));

        final secondPointer = TestPointer(118);
        await tester.sendEventToBinding(
          secondPointer.down(
            center,
            timeStamp: const Duration(milliseconds: 57),
          ),
        );
        output.clear();
        await tester.pump(const Duration(milliseconds: 100));
        final held = output.isEmpty;
        await tester.sendEventToBinding(
          secondPointer.up(timeStamp: const Duration(milliseconds: 157)),
        );

        expect(held, isTrue);
      });

      testWidgets('untracked trackpad pan remains available to scrolling', (
        tester,
      ) async {
        final fixture = await pumpScrollableTerminal(tester);
        final initialPixels = fixture.scrollController.position.pixels;

        final pointer = TestPointer(101, PointerDeviceKind.trackpad);
        final center = tester.getCenter(find.byType(TerminalView));
        await tester.sendEventToBinding(pointer.panZoomStart(center));
        await tester.pump();
        await tester.sendEventToBinding(
          pointer.panZoomUpdate(center, pan: const Offset(0, 100)),
        );
        await tester.pumpAndSettle();
        await tester.sendEventToBinding(pointer.panZoomEnd());
        await tester.pump();

        expect(fixture.scrollController.position.pixels, isNot(initialPixels));
      });

      testWidgets('Shift leaves trackpad pan available to scrolling', (
        tester,
      ) async {
        final fixture = await pumpScrollableTerminal(tester);
        final initialPixels = fixture.scrollController.position.pixels;
        writeUtf8(controller, '\x1b[?1003h\x1b[?1006h');
        await tester.pump();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);

        final output = <Uint8List>[];
        controller.onOutput = output.add;
        final pointer = TestPointer(102, PointerDeviceKind.trackpad);
        final center = tester.getCenter(find.byType(TerminalView));
        await tester.sendEventToBinding(pointer.panZoomStart(center));
        await tester.pump();
        await tester.sendEventToBinding(
          pointer.panZoomUpdate(center, pan: const Offset(0, 100)),
        );
        await tester.pumpAndSettle();
        await tester.sendEventToBinding(pointer.panZoomEnd());
        await tester.pump();
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);

        expect(output, isEmpty);
        expect(fixture.scrollController.position.pixels, isNot(initialPixels));
      });

      testWidgets('virtual Shift leaves trackpad pan available to scrolling', (
        tester,
      ) async {
        final fixture = await pumpScrollableTerminal(tester);
        final initialPixels = fixture.scrollController.position.pixels;
        writeUtf8(controller, '\x1b[?1003h\x1b[?1006h');
        await tester.pump();
        controller.toggleMod(const Mods.shift());

        final output = <Uint8List>[];
        controller.onOutput = output.add;
        final pointer = TestPointer(103, PointerDeviceKind.trackpad);
        final center = tester.getCenter(find.byType(TerminalView));
        await tester.sendEventToBinding(pointer.panZoomStart(center));
        await tester.pump();
        await tester.sendEventToBinding(
          pointer.panZoomUpdate(center, pan: const Offset(0, 100)),
        );
        await tester.pumpAndSettle();
        await tester.sendEventToBinding(pointer.panZoomEnd());
        await tester.pump();

        expect(output, isEmpty);
        expect(fixture.scrollController.position.pixels, isNot(initialPixels));
      });

      testWidgets('pixel offset maps to terminal row after existing scroll', (
        tester,
      ) async {
        final fixture = await pumpScrollableTerminal(tester);
        final targetRow = fixture.terminal.scrollbackRows ~/ 2;
        fixture.terminal.scrollToBottom();

        fixture.scrollController.jumpTo(targetRow * fixture.cellHeight);
        await tester.pump();

        expect(fixture.terminal.scrollbar.offset, targetRow);
      });

      testWidgets('controller viewport commands synchronize Flutter scroll', (
        tester,
      ) async {
        final fixture = await pumpScrollableTerminal(tester);

        controller.scrollToTop();
        await tester.pump();

        expect(fixture.terminal.scrollbar.offset, 0);
        expect(fixture.scrollController.position.pixels, 0);

        controller.scrollToBottom();
        await tester.pump();

        expect(
          fixture.terminal.scrollbar.offset,
          fixture.terminal.scrollbackRows,
        );
        expect(
          fixture.scrollController.position.pixels,
          fixture.scrollController.position.maxScrollExtent,
        );
      });

      testWidgets('negative pixel offset clamps to top row', (tester) async {
        final fixture = await pumpScrollableTerminal(tester);

        fixture.scrollController.jumpTo(-100);
        await tester.pump();

        expect(fixture.terminal.scrollbar.offset, 0);
      });

      testWidgets('overscroll pixel offset clamps to live row', (tester) async {
        final fixture = await pumpScrollableTerminal(tester);
        final position = fixture.scrollController.position;

        fixture.scrollController.jumpTo(position.maxScrollExtent + 100);
        await tester.pump();

        expect(
          fixture.terminal.scrollbar.offset,
          fixture.terminal.scrollbackRows,
        );
      });
    });

    testWidgets('selectAll via controller updates view', (tester) async {
      writeUtf8(controller, 'hello world');
      await tester.pumpWidget(
        wrapInApp(controller: controller, autofocus: true),
      );
      await tester.pumpAndSettle();

      controller.selectAll();
      await tester.pump();

      expect(controller.hasSelection, isTrue);
    });

    testWidgets('selectAll shortcut selects content by default', (
      tester,
    ) async {
      writeUtf8(controller, 'hello world');
      await tester.pumpWidget(
        wrapInApp(controller: controller, autofocus: true),
      );
      await tester.pumpAndSettle();

      await sendSelectAllShortcut(tester);

      expect(controller.hasSelection, isTrue);
    });

    testWidgets('selectAll shortcut blocked when selectAllShortcut is false', (
      tester,
    ) async {
      writeUtf8(controller, 'hello world');
      await tester.pumpWidget(
        wrapInApp(
          controller: controller,
          autofocus: true,
          gestureSettings: const TerminalGestureSettings(
            selectAllShortcut: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await sendSelectAllShortcut(tester);

      expect(controller.hasSelection, isFalse);
    });

    testWidgets('typing clears selection when selectionClearOnTyping is true', (
      tester,
    ) async {
      writeUtf8(controller, 'hello world');
      await tester.pumpWidget(
        wrapInApp(controller: controller, autofocus: true),
      );
      await tester.pumpAndSettle();

      controller.selectRange(
        start: const Position(row: 0, col: 0),
        end: const Position(row: 0, col: 4),
      );
      expect(controller.hasSelection, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pump();

      expect(controller.hasSelection, isFalse);
    });

    testWidgets('shift+arrow extends existing selection', (tester) async {
      writeUtf8(controller, 'hello world');
      await tester.pumpWidget(
        wrapInApp(controller: controller, autofocus: true),
      );
      await tester.pumpAndSettle();

      controller.selectRange(
        start: const Position(row: 0, col: 0),
        end: const Position(row: 0, col: 4),
      );

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await tester.pump();

      expect(activeSelection(controller)!.endCol, 6);
    });

    group('virtual mods', () {
      testWidgets('focus loss clears virtual mods', (tester) async {
        final focusNode = FocusNode();
        addTearDown(focusNode.dispose);
        await tester.pumpWidget(
          wrapInApp(
            controller: controller,
            focusNode: focusNode,
            autofocus: true,
          ),
        );
        await tester.pump();

        controller.toggleMod(const Mods.ctrl());
        expect(controller.virtualMods.hasCtrl, isTrue);

        focusNode.unfocus();
        await tester.pumpAndSettle();

        expect(controller.virtualMods, const Mods.none());
      });
    });

    group('mouse cursor', () {
      MouseCursor findMouseCursor(WidgetTester tester) {
        final mouseRegion = tester.widget<MouseRegion>(
          find.descendant(
            of: find.byType(TerminalView),
            matching: find.byType(MouseRegion),
          ),
        );
        return mouseRegion.cursor;
      }

      testWidgets('defaults to text cursor', (tester) async {
        await tester.pumpWidget(wrapInApp(controller: controller));
        expect(findMouseCursor(tester), SystemMouseCursors.text);
      });

      testWidgets('switches to basic when mouse tracking is active', (
        tester,
      ) async {
        await tester.pumpWidget(wrapInApp(controller: controller));
        expect(findMouseCursor(tester), SystemMouseCursors.text);

        writeUtf8(controller, '\x1b[?1000h');
        await tester.pumpAndSettle();

        expect(findMouseCursor(tester), SystemMouseCursors.basic);
      });

      testWidgets('hides cursor on key input when mouseAutoHide is onInput', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrapInApp(controller: controller, autofocus: true),
        );
        await tester.pump();
        expect(findMouseCursor(tester), SystemMouseCursors.text);

        await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
        await tester.pump();

        expect(findMouseCursor(tester), SystemMouseCursors.none);
      });

      testWidgets('shows cursor on mouse hover after hiding', (tester) async {
        await tester.pumpWidget(
          wrapInApp(controller: controller, autofocus: true),
        );
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
        await tester.pump();
        expect(findMouseCursor(tester), SystemMouseCursors.none);

        final center = tester.getCenter(find.byType(TerminalView));
        final gesture = await tester.createGesture(kind: .mouse);
        await gesture.addPointer(location: center);
        await gesture.moveTo(center + const Offset(10, 0));
        await tester.pump();

        expect(findMouseCursor(tester), isNot(SystemMouseCursors.none));
        await gesture.removePointer();
      });

      testWidgets('does not hide cursor when mouseAutoHide is never', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrapInApp(
            controller: controller,
            autofocus: true,
            mouseAutoHide: .never,
          ),
        );
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
        await tester.pump();

        expect(findMouseCursor(tester), isNot(SystemMouseCursors.none));
      });
    });

    group('paste', () {
      Future<void> mockClipboard(WidgetTester tester, String text) async {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.getData') {
              return <String, dynamic>{'text': text};
            }
            return null;
          },
        );
      }

      Future<void> sendPasteShortcut(WidgetTester tester) async {
        switch (defaultTargetPlatform) {
          case TargetPlatform.macOS || TargetPlatform.iOS:
            await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
            await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
            await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
          case TargetPlatform.linux || TargetPlatform.fuchsia:
            await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
            await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
            await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
            await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
            await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
          case TargetPlatform.windows || TargetPlatform.android:
            await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
            await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
            await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
        }
        await tester.pump();
      }

      tearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      testWidgets('paste shortcut sends clipboard text to onOutput', (
        tester,
      ) async {
        await mockClipboard(tester, 'pasted');
        final output = <Uint8List>[];
        controller.onOutput = output.add;

        await tester.pumpWidget(
          wrapInApp(controller: controller, autofocus: true),
        );
        await tester.pump();

        await sendPasteShortcut(tester);
        await tester.pumpAndSettle();

        final pasted = output.where((b) => utf8.decode(b).contains('pasted'));
        expect(pasted, isNotEmpty);
      });

      testWidgets('paste wraps with bracketed paste when mode is active', (
        tester,
      ) async {
        writeUtf8(controller, '\x1b[?2004h');
        await mockClipboard(tester, 'hello');
        final output = <Uint8List>[];
        controller.onOutput = output.add;

        await tester.pumpWidget(
          wrapInApp(controller: controller, autofocus: true),
        );
        await tester.pump();

        await sendPasteShortcut(tester);
        await tester.pumpAndSettle();

        final pasted = output
            .map((b) => utf8.decode(b))
            .where((s) => s.contains('hello'));
        expect(pasted, isNotEmpty);
        expect(pasted.first, contains('\x1b[200~'));
        expect(pasted.first, contains('\x1b[201~'));
      });

      testWidgets('paste with empty clipboard produces no output', (
        tester,
      ) async {
        await mockClipboard(tester, '');
        final output = <Uint8List>[];
        controller.onOutput = output.add;

        await tester.pumpWidget(
          wrapInApp(controller: controller, autofocus: true),
        );
        await tester.pump();

        await sendPasteShortcut(tester);
        await tester.pumpAndSettle();

        final pasted = output.where(
          (b) => utf8.decode(b).contains('\x1b[200~'),
        );
        expect(pasted, isEmpty);
      });
    });

    group('padding', () {
      testWidgets('padding reduces reported grid size', (tester) async {
        final cols = <int>[];
        final rows = <int>[];
        controller.onResize = (c, r) {
          cols.add(c);
          rows.add(r);
        };

        await tester.pumpWidget(wrapInApp(controller: controller));
        await tester.pumpAndSettle();
        final noPaddingCols = cols.last;
        final noPaddingRows = rows.last;

        cols.clear();
        rows.clear();
        await tester.pumpWidget(
          wrapInApp(controller: controller, padding: const EdgeInsets.all(20)),
        );
        await tester.pumpAndSettle();

        expect(cols.last, lessThan(noPaddingCols));
        expect(rows.last, lessThan(noPaddingRows));
      });
    });

    group('transparent background', () {
      testWidgets('opaque theme paints ColoredBox with theme.background', (
        tester,
      ) async {
        final theme = TerminalTheme.dark();
        await tester.pumpWidget(
          wrapInApp(controller: controller, theme: theme),
        );
        await tester.pumpAndSettle();

        final box = tester.widget<ColoredBox>(
          find.descendant(
            of: find.byType(TerminalView),
            matching: find.byType(ColoredBox),
          ),
        );
        expect(box.color, theme.background);
      });

      testWidgets('backgroundOpacity < 1 scales backdrop alpha to match', (
        tester,
      ) async {
        final theme = TerminalTheme.dark().copyWith(backgroundOpacity: 0.5);
        await tester.pumpWidget(
          wrapInApp(controller: controller, theme: theme),
        );
        await tester.pumpAndSettle();

        final box = tester.widget<ColoredBox>(
          find.descendant(
            of: find.byType(TerminalView),
            matching: find.byType(ColoredBox),
          ),
        );
        expect(box.color.a, closeTo(0.5, 0.01));
        expect(box.color.r, theme.background.r);
        expect(box.color.g, theme.background.g);
        expect(box.color.b, theme.background.b);
      });
    });
  });
}

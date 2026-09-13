@Tags(['ffi'])
library;

import 'dart:convert';

import 'package:flterm/src/controller/terminal_controller.dart';
import 'package:flterm/src/input/keyboard_input_adapter.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show KeyEventResult;
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KeyboardInputAdapter dead keys', () {
    late TerminalControllerImpl controller;
    late KeyboardInputAdapter adapter;
    late List<int> output;

    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      controller = TerminalControllerImpl();
      output = <int>[];
      controller.onOutput = output.addAll;
      adapter = KeyboardInputAdapter(controller);
      // Enable the Kitty keyboard protocol so an unmodified printable press
      // would otherwise be encoded and sent to the PTY.
      controller.write(Uint8List.fromList(utf8.encode('\x1b[>1u')));
    });

    tearDown(() {
      adapter.dispose();
      controller.dispose();
      debugDefaultTargetPlatformOverride = null;
    });

    KeyDownEvent keyDown(
      PhysicalKeyboardKey physical,
      LogicalKeyboardKey logical, {
      String? character,
    }) {
      return KeyDownEvent(
        physicalKey: physical,
        logicalKey: logical,
        character: character,
        timeStamp: Duration.zero,
      );
    }

    test('dead key with a null character is ignored and reaches no PTY', () {
      // The acute/tilde dead key sits on the bracketLeft physical position and
      // fires a key-down with no composed character yet.
      final result = adapter.handleKeyEvent(
        keyDown(
          PhysicalKeyboardKey.bracketLeft,
          LogicalKeyboardKey.bracketLeft,
        ),
      );

      expect(result, KeyEventResult.ignored);
      expect(output, isEmpty);
    });

    test('dead key delivered as a bare acute is ignored', () {
      final result = adapter.handleKeyEvent(
        keyDown(
          PhysicalKeyboardKey.bracketLeft,
          LogicalKeyboardKey.bracketLeft,
          character: '´',
        ),
      );

      expect(result, KeyEventResult.ignored);
      expect(output, isEmpty);
    });

    test('plain printable key still encodes to the PTY under Kitty', () {
      final result = adapter.handleKeyEvent(
        keyDown(
          PhysicalKeyboardKey.keyA,
          LogicalKeyboardKey.keyA,
          character: 'a',
        ),
      );

      expect(result, KeyEventResult.handled);
      expect(output, isNotEmpty);
    });

    test('Enter is not treated as a dead key and reaches the PTY', () {
      final result = adapter.handleKeyEvent(
        keyDown(PhysicalKeyboardKey.enter, LogicalKeyboardKey.enter),
      );

      expect(result, KeyEventResult.handled);
      expect(output, isNotEmpty);
    });
  });

  group('KeyboardInputAdapter super shortcuts', () {
    late TerminalControllerImpl controller;
    late KeyboardInputAdapter adapter;
    late List<int> output;

    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      controller = TerminalControllerImpl();
      output = <int>[];
      controller.onOutput = output.addAll;
      adapter = KeyboardInputAdapter(controller);
    });

    tearDown(() {
      adapter.dispose();
      controller.dispose();
      HardwareKeyboard.instance.clearState();
      debugDefaultTargetPlatformOverride = null;
    });

    KeyDownEvent keyDown(
      PhysicalKeyboardKey physical,
      LogicalKeyboardKey logical, {
      String? character,
    }) {
      return KeyDownEvent(
        physicalKey: physical,
        logicalKey: logical,
        character: character,
        timeStamp: Duration.zero,
      );
    }

    test('Cmd+` is ignored and reaches no PTY', () async {
      await simulateKeyDownEvent(LogicalKeyboardKey.metaLeft);

      final result = adapter.handleKeyEvent(
        keyDown(
          PhysicalKeyboardKey.backquote,
          LogicalKeyboardKey.backquote,
          character: '`',
        ),
      );

      expect(result, KeyEventResult.ignored);
      expect(output, isEmpty);
    });

    test('Cmd+` under Kitty is ignored and reaches no PTY', () async {
      controller.write(Uint8List.fromList(utf8.encode('\x1b[>1u')));
      await simulateKeyDownEvent(LogicalKeyboardKey.metaLeft);

      final result = adapter.handleKeyEvent(
        keyDown(
          PhysicalKeyboardKey.backquote,
          LogicalKeyboardKey.backquote,
          character: '`',
        ),
      );

      expect(result, KeyEventResult.ignored);
      expect(output, isEmpty);
    });

    test('Ctrl+C still reaches the PTY', () async {
      await simulateKeyDownEvent(LogicalKeyboardKey.controlLeft);

      final result = adapter.handleKeyEvent(
        keyDown(PhysicalKeyboardKey.keyC, LogicalKeyboardKey.keyC),
      );

      expect(result, KeyEventResult.handled);
      expect(output, [0x03]);
    });

    test('Cmd+Left still encodes to the PTY', () async {
      await simulateKeyDownEvent(LogicalKeyboardKey.metaLeft);

      final result = adapter.handleKeyEvent(
        keyDown(PhysicalKeyboardKey.arrowLeft, LogicalKeyboardKey.arrowLeft),
      );

      expect(result, KeyEventResult.handled);
      expect(utf8.decode(output), '\x1b[1;9D');
    });
  });
}

@Tags(['ffi'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flterm/src/controller/terminal_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show KeyEventResult;
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart' show Key, Mods;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Ctrl+Space', () {
    late TerminalController controller;
    late ViewAttachment attachment;
    late List<int> output;

    setUp(() {
      controller = TerminalController();
      attachment = ViewAttachment(controller);
      output = <int>[];
      controller.onOutput = output.addAll;
    });

    tearDown(() {
      attachment.dispose();
      controller.dispose();
      HardwareKeyboard.instance.clearState();
    });

    for (final kitty in [false, true]) {
      for (final character in <String?>[' ', null, '\x00']) {
        test('encodes physical chord (Kitty: $kitty, character: '
            '${character?.codeUnits})', () async {
          if (kitty) {
            controller.write(Uint8List.fromList(utf8.encode('\x1b[=1u')));
          }
          await simulateKeyDownEvent(LogicalKeyboardKey.controlLeft);
          final result = attachment.handleKeyEvent(
            KeyDownEvent(
              physicalKey: PhysicalKeyboardKey.space,
              logicalKey: LogicalKeyboardKey.space,
              character: character,
              timeStamp: Duration.zero,
            ),
          );
          expect(result, KeyEventResult.handled);
          expect(output, kitty ? utf8.encode('\x1b[32;5u') : [0]);
        });
      }

      test('encodes programmatic chord (Kitty: $kitty)', () {
        if (kitty) {
          controller.write(Uint8List.fromList(utf8.encode('\x1b[=1u')));
        }
        controller.sendKey(Key.space, mods: const Mods.ctrl());
        expect(output, kitty ? utf8.encode('\x1b[32;5u') : [0]);
      });

      test('unmodified Space still encodes as Space (Kitty: $kitty)', () {
        if (kitty) {
          controller.write(Uint8List.fromList(utf8.encode('\x1b[=1u')));
        }
        final result = attachment.handleKeyEvent(
          const KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.space,
            logicalKey: LogicalKeyboardKey.space,
            character: ' ',
            timeStamp: Duration.zero,
          ),
        );
        expect(result, KeyEventResult.handled);
        expect(output, [0x20]);
      });
    }

    test('Ctrl+C still encodes as ETX', () async {
      await simulateKeyDownEvent(LogicalKeyboardKey.controlLeft);
      final result = attachment.handleKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyC,
          logicalKey: LogicalKeyboardKey.keyC,
          timeStamp: Duration.zero,
        ),
      );
      expect(result, KeyEventResult.handled);
      expect(output, [0x03]);
    });
  });
}

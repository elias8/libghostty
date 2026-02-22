@Tags(['ffi'])
library;

import 'dart:convert';

import 'package:libghostty/parsing.dart';
import 'package:test/test.dart';

void main() {
  group('OscParser', () {
    late OscParser parser;

    setUp(() {
      parser = OscParser();
    });

    tearDown(() {
      parser.dispose();
    });

    test('parses window title change', () {
      final bytes = utf8.encode('0;My Terminal Title');
      parser.feedBytes(bytes);

      final command = parser.end(0x07);
      expect(command.type, OscCommandType.changeWindowTitle);
      expect(command.windowTitle, 'My Terminal Title');
    });

    test('parses window icon change', () {
      final bytes = utf8.encode('1;icon-name');
      parser.feedBytes(bytes);

      final command = parser.end(0x07);
      expect(command.type, OscCommandType.changeWindowIcon);
    });

    test('invalid sequence returns invalid type', () {
      parser.feedByte(0xFF);
      final command = parser.end(0x07);
      expect(command.type, OscCommandType.invalid);
    });

    test('reset allows reuse', () {
      parser.feedBytes(utf8.encode('0;First'));
      final first = parser.end(0x07);
      expect(first.type, OscCommandType.changeWindowTitle);

      parser.reset();
      parser.feedBytes(utf8.encode('0;Second'));
      final second = parser.end(0x07);
      expect(second.type, OscCommandType.changeWindowTitle);
      expect(second.windowTitle, 'Second');
    });

    test('windowTitle returns null for non-title commands', () {
      parser.feedBytes(utf8.encode('7;file:///home'));
      final command = parser.end(0x07);
      expect(command.type, OscCommandType.reportPwd);
      expect(command.windowTitle, isNull);
    });
  });
}

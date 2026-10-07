import 'dart:convert';

import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

import '../helpers/setup.dart';

void main() {
  setUp(() => testEnvironment);

  group('OscParser', () {
    late OscParser parser;

    setUp(() => parser = OscParser());

    tearDown(() => parser.dispose());

    group('end', () {
      test('returns window commands', () {
        parser.feedBytes(utf8.encode('0;My Terminal Title'));

        final title = parser.end(0x07);
        expect(title.type, OscCommandType.changeWindowTitle);
        expect(title.windowTitle, 'My Terminal Title');

        parser.reset();
        parser.feedBytes(utf8.encode('1;icon-name'));

        final icon = parser.end(0x07);
        expect(icon.type, OscCommandType.changeWindowIcon);
      });

      test('returns invalid command for invalid sequence', () {
        parser.feedByte(0xFF);
        final command = parser.end(0x07);
        expect(command.type, OscCommandType.invalid);
      });

      test('captures unknown commands when configured', () {
        final parser = OscParser(unknownMaxBytes: 64);
        addTearDown(parser.dispose);

        parser.feedBytes(utf8.encode('7400;status=busy'));
        final command = parser.end(0x07);

        expect(command.type, OscCommandType.unknown);
        expect(command.unknownContent, utf8.encode('7400;status=busy'));
        expect(command.unknownTruncated, isFalse);
        expect(command.unknownTerminator, OscTerminator.bel);
      });

      test('copies truncated content and preserves its terminator', () {
        final parser = OscParser(unknownMaxBytes: 4);
        addTearDown(parser.dispose);

        parser.feedBytes(utf8.encode('7400;status=busy'));
        final command = parser.end(0x5c);
        parser.reset();

        expect(command.unknownContent, utf8.encode('7400'));
        expect(command.unknownTruncated, isTrue);
        expect(command.unknownTerminator, OscTerminator.st);
      });

      test('unknown capture remains disabled by default', () {
        parser.feedBytes(utf8.encode('7400;status=busy'));

        final command = parser.end(0x07);

        expect(command.type, OscCommandType.invalid);
        expect(command.unknownContent, isNull);
        expect(command.unknownTruncated, isNull);
        expect(command.unknownTerminator, isNull);
      });

      test('discards cancelled sequences', () {
        for (final terminator in [0x18, 0x1a]) {
          parser.feedBytes(utf8.encode('7400;status=busy'));

          final command = parser.end(terminator);

          expect(command.type, OscCommandType.invalid);
          expect(command.unknownContent, isNull);
          parser.reset();
        }
      });
    });

    group('reset', () {
      test('clears previous command state', () {
        parser.feedBytes(utf8.encode('0;First'));
        parser.end(0x07);

        parser.reset();
        parser.feedBytes(utf8.encode('0;Second'));

        final second = parser.end(0x07);
        expect(second.windowTitle, 'Second');
      });
    });

    group('windowTitle', () {
      test('returns null for non-title commands', () {
        parser.feedBytes(utf8.encode('7;file:///home'));
        final command = parser.end(0x07);
        expect(command.type, OscCommandType.reportPwd);
        expect(command.windowTitle, isNull);
      });
    });

    group('dispose', () {
      test('is idempotent', () {
        parser.dispose();

        parser.dispose();
      });

      test('rejects all operations after disposal', () {
        parser.dispose();

        expect(() => parser.reset(), throwsStateError);
        expect(() => parser.end(0x07), throwsStateError);
        expect(() => parser.feedByte(0), throwsStateError);
        expect(() => parser.feedBytes(const [0]), throwsStateError);
      });
    });
  });
}

@Tags(['ffi'])
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

import '../helpers/setup.dart';

void main() {
  setUp(() => testEnvironment);

  group('LibGhostty', () {
    late Terminal terminal;

    setUp(() => terminal = Terminal(cols: 80, rows: 24));

    tearDown(() {
      terminal.dispose();
      LibGhostty.clearLogger();
    });

    group('setLogger', () {
      test(
        'receives validation logs outside terminal input processing',
        () async {
          final delivered = Completer<String>();
          LibGhostty.setLogger((_, _, message) => delivered.complete(message));
          final parser = SgrParser();
          addTearDown(parser.dispose);

          expect(
            () => parser.parse(
              List<int>.filled(1000, 1),
              separators: List<String>.filled(1000, ';'),
            ),
            throwsA(isA<InvalidValueException>()),
          );
          expect(
            await delivered.future,
            contains('exceeds max supported length'),
          );
          expect(parser.parse([1]).single.tag, SgrAttributeTag.bold);
        },
      );

      test('receives decoded log emissions from current logger', () async {
        final replaced = <String>[];
        final delivered = Completer<_LogEntry>();
        LibGhostty.setLogger((_, _, msg) => replaced.add(msg));
        LibGhostty.setLogger((level, scope, message) {
          delivered.complete((level: level, scope: scope, message: message));
        });

        terminal.write(_logTrigger);
        final captured = await delivered.future;

        expect(replaced, isEmpty);
        expect(captured.level, SysLogLevel.warning);
        expect(captured.scope, 'stream');
        expect(captured.message, contains('invalid C0 character'));
      });
    });

    group('clearLogger', () {
      test('stops delivering messages', () {
        final captured = <String>[];
        LibGhostty.setLogger((_, _, msg) => captured.add(msg));
        LibGhostty.clearLogger();

        terminal.write(_logTrigger);

        expect(captured, isEmpty);
      });

      test('can be called without installed logger', () {
        expect(LibGhostty.clearLogger, returnsNormally);
      });
    });

    group('useStderrLogger', () {
      test('accepts emissions', () {
        LibGhostty.useStderrLogger();
        expect(() => terminal.write(_logTrigger), returnsNormally);
      });

      test('replaces previous logger', () {
        final captured = <String>[];
        LibGhostty.setLogger((_, _, msg) => captured.add(msg));
        LibGhostty.useStderrLogger();

        terminal.write(_logTrigger);

        expect(captured, isEmpty);
      });
    });
  });
}

final _logTrigger = Uint8List.fromList([0x03]);

typedef _LogEntry = ({SysLogLevel level, String scope, String message});

import 'dart:convert' show utf8;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../../../tool/benchmarks/fixture/terminal.dart'
    show TerminalBenchmarkFixture;

void main() {
  group('TerminalBenchmarkFixture', () {
    group('streamingOutput', () {
      test('provides the streaming benchmark corpus', () {
        final bytes = TerminalBenchmarkFixture.streamingOutput;
        final text = utf8.decode(bytes);

        expect(bytes, hasLength(4 * 1024 * 1024));
        expect(() => bytes[0] = bytes[0], throwsUnsupportedError);
        expect(text, contains('\x1b[38;5;39m'));
        expect(text, contains('\x1b[38;2;'));
        expect(text, contains('\x1b[32m'));
        expect(text, contains('界'));
        expect(text, contains('e\u0301'));
      });
    });

    group('interactiveTuiOutput', () {
      test('provides the interactive TUI benchmark corpus', () {
        final bytes = TerminalBenchmarkFixture.interactiveTuiOutput;
        final text = utf8.decode(bytes);

        expect(bytes, hasLength(4 * 1024 * 1024));
        expect(() => bytes[0] = bytes[0], throwsUnsupportedError);
        expect(text, contains('\x1b[?1049h'));
        expect(text, contains('\x1b[?2026h'));
      });
    });

    group('chunks', () {
      test('creates fixed-size views over every input byte', () {
        final input = Uint8List.fromList([1, 2, 3, 4]);

        final result = TerminalBenchmarkFixture.chunks(input, 2);

        expect(result.map((chunk) => chunk.length), [2, 2]);
        expect(result.expand((chunk) => chunk), orderedEquals(input));
      });

      test('rejects a partial final chunk', () {
        expect(
          () => TerminalBenchmarkFixture.chunks(Uint8List(3), 2),
          throwsA(
            isA<ArgumentError>().having(
              (error) => error.message,
              'message',
              contains('divisible by chunkSize'),
            ),
          ),
        );
      });
    });

    group('partialFrames', () {
      test('creates the requested three-row updates', () {
        final result = TerminalBenchmarkFixture.partialFrames(count: 12);
        final addresses = RegExp(
          r'\x1b\[\d+;1H',
        ).allMatches(utf8.decode(result.first));

        expect(result, hasLength(12));
        expect(addresses, hasLength(3));
      });
    });

    group('fullFrames', () {
      test('addresses every terminal row', () {
        final result = TerminalBenchmarkFixture.fullFrames(count: 1);

        final addresses = RegExp(
          r'\x1b\[\d+;1H',
        ).allMatches(utf8.decode(result.single));

        expect(addresses, hasLength(80));
      });

      test('rejects a non-positive frame count', () {
        expect(
          () => TerminalBenchmarkFixture.fullFrames(count: 0),
          throwsRangeError,
        );
      });
    });

    group('glyphMissFrames', () {
      test('creates distinct frames covering uncached glyph classes', () {
        final result = TerminalBenchmarkFixture.glyphMissFrames(count: 120);
        final text = utf8.decode(result.expand((frame) => frame).toList());

        expect(result.toSet(), hasLength(120));
        expect(text, contains('一'));
        expect(text, contains('😀'));
      });
    });

    group('inputDigest', () {
      const fixtureDigest =
          'sha256:2ab7fcf523ee15f013dea8481916414a'
          '851b357db62e08603ff2d104ceba50cf';

      test('captures fixture and font identity', () {
        final first = TerminalBenchmarkFixture.benchmarkDigest(
          'sha256:font-one',
        );
        final second = TerminalBenchmarkFixture.benchmarkDigest(
          'sha256:font-two',
        );

        expect(TerminalBenchmarkFixture.inputDigest, fixtureDigest);
        expect(first, isNot(second));
      });
    });
  });
}

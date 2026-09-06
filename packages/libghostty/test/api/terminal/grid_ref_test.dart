import 'dart:typed_data' show Uint8List;

import 'package:libghostty/libghostty.dart'
    show CellWidth, GridRef, InvalidValueException, Position, Style, Terminal;
import 'package:test/test.dart';

import '../../helpers/setup.dart';

void main() {
  setUp(() => testEnvironment);

  group('GridRef', () {
    late Terminal terminal;

    setUp(() {
      terminal = Terminal(cols: 80, rows: 24);
      terminal.write(Uint8List.fromList('Hello'.codeUnits));
    });

    tearDown(() {
      terminal.dispose();
    });

    group('at', () {
      test('returns content for a resolved cell', () {
        final ref = GridRef.at(terminal, const Position(row: 0, col: 0));

        final result = ref.content;

        expect(result, 'H');
      });

      test('returns empty content for an empty cell', () {
        final ref = GridRef.at(terminal, const Position(row: 23, col: 79));

        final result = ref.content;

        expect(result, isEmpty);
      });

      test('throws for an out of range column', () {
        expect(
          () => GridRef.at(terminal, const Position(row: 0, col: 80)),
          throwsA(isA<InvalidValueException>()),
        );
      });
    });

    group('style', () {
      test('returns the cell style', () {
        terminal.write(Uint8List.fromList('\x1b[1mB'.codeUnits));
        final ref = GridRef.at(terminal, const Position(row: 0, col: 5));

        final result = ref.style;

        expect(result, isA<Style>());
      });

      test('reflects bold text', () {
        terminal.write(Uint8List.fromList('\x1b[1mB'.codeUnits));
        final ref = GridRef.at(terminal, const Position(row: 0, col: 5));

        final result = ref.style.bold;

        expect(result, isTrue);
      });
    });

    group('graphemes', () {
      test('returns the cell codepoints', () {
        final ref = GridRef.at(terminal, const Position(row: 0, col: 0));

        final result = ref.graphemes;

        expect(result, contains(0x48));
      });
    });

    group('hyperlinkUri', () {
      test('returns null when the cell has no hyperlink', () {
        final ref = GridRef.at(terminal, const Position(row: 0, col: 0));

        final result = ref.hyperlinkUri;

        expect(result, isNull);
      });
    });

    group('wide', () {
      test('returns narrow for a single width cell', () {
        final ref = GridRef.at(terminal, const Position(row: 0, col: 0));

        final result = ref.wide;

        expect(result, CellWidth.narrow);
      });

      test('returns wide for a leading wide cell', () {
        terminal.write(Uint8List.fromList([0xE6, 0x97, 0xA5]));
        final ref = GridRef.at(terminal, const Position(row: 0, col: 5));

        final result = ref.wide;

        expect(result, CellWidth.wide);
      });
    });

    group('isWide', () {
      test('returns false for a single width cell', () {
        final ref = GridRef.at(terminal, const Position(row: 0, col: 0));

        final result = ref.isWide;

        expect(result, isFalse);
      });

      test('returns true for a leading wide cell', () {
        terminal.write(Uint8List.fromList([0xE6, 0x97, 0xA5]));
        final ref = GridRef.at(terminal, const Position(row: 0, col: 5));

        final result = ref.isWide;

        expect(result, isTrue);
      });
    });

    group('rowWrap', () {
      test('returns true for a wrapped row', () {
        final wrapped = Terminal(cols: 5, rows: 2);
        addTearDown(wrapped.dispose);
        wrapped.write(Uint8List.fromList('ABCDEF'.codeUnits));
        final ref = GridRef.at(wrapped, const Position(row: 0, col: 0));

        final result = ref.rowWrap;

        expect(result, isTrue);
      });
    });

    group('positionIn', () {
      test('returns coordinates in the requested coordinate space', () {
        final ref = GridRef.at(terminal, const Position(row: 0, col: 2));

        final result = ref.positionIn(.active);

        expect(result, const Position(row: 0, col: 2));
      });

      test('returns null outside the requested coordinate space', () {
        final scrolled = Terminal(cols: 5, rows: 2);
        addTearDown(scrolled.dispose);
        scrolled.write(
          Uint8List.fromList('first\r\nsecond\r\nthird'.codeUnits),
        );
        final ref = GridRef.at(
          scrolled,
          const Position(row: 0, col: 0),
          pointTag: .screen,
        );
        scrolled.scrollToBottom();

        final result = ref.positionIn(.viewport);

        expect(result, isNull);
      });
    });
  });
}

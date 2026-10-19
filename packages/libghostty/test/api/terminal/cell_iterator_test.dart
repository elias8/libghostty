import 'dart:convert' show utf8;

import 'dart:typed_data' show Uint8List;

import 'package:libghostty/libghostty.dart'
    show
        CellIterator,
        GridRef,
        Position,
        RenderState,
        RowIterator,
        Selection,
        SemanticContent,
        Terminal;
import 'package:test/test.dart';

import '../../helpers/setup.dart';

void main() {
  setUp(() => testEnvironment);

  group('CellIterator', () {
    late Terminal terminal;
    late RenderState renderState;
    late RowIterator rows;
    late CellIterator cells;

    setUp(() {
      terminal = Terminal(cols: 10, rows: 3);
      renderState = RenderState();
      rows = RowIterator();
      cells = CellIterator();
    });

    tearDown(() {
      cells.dispose();
      rows.dispose();
      renderState.dispose();
      terminal.dispose();
    });

    void installSelection() {
      terminal.selection = Selection.fromRefs(
        start: GridRef.at(terminal, const Position(row: 1, col: 1)),
        end: GridRef.at(terminal, const Position(row: 1, col: 3)),
      );
    }

    void bindSelectedRow() {
      renderState.update(terminal);
      rows.reset(renderState);
      expect(rows.next(), isTrue);
      expect(rows.next(), isTrue);
      cells.reset(rows);
    }

    void bindFirstCell() {
      renderState.update(terminal);
      rows.reset(renderState);
      rows.next();
      cells.reset(rows);
      cells.next();
    }

    test('independent iterators preserve rows when another row is bound', () {
      final otherRows = RowIterator();
      final otherCells = CellIterator();
      addTearDown(() {
        otherCells.dispose();
        otherRows.dispose();
      });
      terminal.write(Uint8List.fromList(utf8.encode('alpha\r\nbravo')));
      renderState.update(terminal);
      rows.reset(renderState);
      expect(rows.next(), isTrue);
      cells.reset(rows);
      otherRows.reset(renderState);
      expect(otherRows.next(), isTrue);
      expect(otherRows.next(), isTrue);
      otherCells.reset(otherRows);
      for (var col = 0; col < 5; col++) {
        expect(cells.next(), isTrue);
        expect(cells.content, 'alpha'[col]);
        expect(otherCells.next(), isTrue);
        expect(otherCells.content, 'bravo'[col]);
      }
      terminal.write(Uint8List.fromList(utf8.encode('\x1b[HGAMMA')));
      renderState.update(terminal);
      expect(otherCells.next, throwsStateError);
      rows.reset(renderState);
      expect(rows.next(), isTrue);
      cells.reset(rows);
      for (var col = 0; col < 5; col++) {
        expect(cells.next(), isTrue);
        expect(cells.content, 'GAMMA'[col]);
      }
      otherRows.reset(renderState);
      expect(otherRows.next(), isTrue);
      expect(otherRows.next(), isTrue);
      otherCells.reset(otherRows);
      expect(otherCells.next(), isTrue);
      expect(otherCells.content, 'b');
    });

    test('rejects cells after their render state is disposed', () {
      terminal.write(Uint8List.fromList('hello'.codeUnits));
      bindFirstCell();
      expect(cells.content, 'h');

      renderState.dispose();

      expect(() => cells.content, throwsStateError);
      expect(() => cells.col, throwsStateError);
      expect(cells.next, throwsStateError);
      expect(() => cells.select(0), throwsStateError);
    });

    test('rejects cells until rebound after a render update', () {
      terminal.write(Uint8List.fromList('hello'.codeUnits));
      bindFirstCell();
      expect(cells.content, 'h');

      renderState.update(terminal);
      expect(() => cells.content, throwsStateError);
      rows.reset(renderState);
      expect(rows.next(), isTrue);
      expect(() => cells.content, throwsStateError);
      cells.reset(rows);
      expect(cells.next(), isTrue);
      expect(cells.content, 'h');
    });

    group('isSelected', () {
      test('returns true for a selected cell', () {
        installSelection();
        bindSelectedRow();
        cells.select(2);

        final result = cells.isSelected;

        expect(result, isTrue);
      });

      test('returns true for the selected end column', () {
        installSelection();
        bindSelectedRow();
        cells.select(3);

        final result = cells.isSelected;

        expect(result, isTrue);
      });

      test('returns false for an unselected cell', () {
        installSelection();
        bindSelectedRow();
        cells.select(4);

        final result = cells.isSelected;

        expect(result, isFalse);
      });
    });

    group('properties', () {
      test('returns default cell properties', () {
        terminal.write(Uint8List.fromList('A'.codeUnits));
        bindFirstCell();

        expect(cells.style.bold, isFalse);
        expect(cells.isProtected, isFalse);
        expect(cells.semanticContent, SemanticContent.output);
        expect(cells.backgroundArgb, isNull);
        expect(cells.foregroundArgb, isNull);
      });

      test('reports styled cells', () {
        terminal.write(Uint8List.fromList('\x1b[1mB'.codeUnits));
        bindFirstCell();

        final result = cells.hasStyling;

        expect(result, isTrue);
      });

      test('returns primary codepoint', () {
        terminal.write(Uint8List.fromList('Z'.codeUnits));
        bindFirstCell();

        final result = cells.codepoint;

        expect(result, 0x5A);
      });

      test('returns zero codepoint for an empty cell', () {
        terminal.write(Uint8List.fromList('Z'.codeUnits));
        bindFirstCell();
        cells.next();

        final result = cells.codepoint;

        expect(result, 0);
      });

      test('tracks column position', () {
        terminal.write(Uint8List.fromList('ABC'.codeUnits));
        bindFirstCell();
        final first = cells.col;
        cells.next();

        final second = cells.col;

        expect(first, 0);
        expect(second, 1);
      });

      test('returns grapheme length for text', () {
        terminal.write(Uint8List.fromList('A'.codeUnits));
        bindFirstCell();

        final result = cells.graphemeLength;

        expect(result, 1);
      });

      test('returns zero grapheme length for an empty cell', () {
        terminal.write(Uint8List.fromList('A'.codeUnits));
        bindFirstCell();
        cells.next();

        final result = cells.graphemeLength;

        expect(result, 0);
      });

      test('returns packed ARGB colors', () {
        terminal.write(
          Uint8List.fromList(
            '\x1b[48;2;255;128;0m\x1b[38;2;0;255;64mY'.codeUnits,
          ),
        );
        bindFirstCell();

        expect(cells.backgroundArgb, 0xFFFF8000);
        expect(cells.foregroundArgb, 0xFF00FF40);
      });
    });

    test(
      'preserves style and graphemes after advancing through plain cells',
      () {
        terminal.write(
          utf8.encode('AB\x1b[1;38;2;7;8;9;48;2;10;11;12me\u0301Z'),
        );
        bindFirstCell();
        expect(cells.content, 'A');
        expect(cells.next(), isTrue);
        expect(cells.content, 'B');
        expect(cells.next(), isTrue);
        expect(cells.graphemeLength, 2);
        expect(cells.content, 'e\u0301');
        expect(cells.style.bold, isTrue);
        expect(cells.foregroundArgb, 0xff070809);
        expect(cells.backgroundArgb, 0xff0a0b0c);
        expect(cells.next(), isTrue);
        expect(cells.content, 'Z');
        expect(cells.style.bold, isTrue);
        expect(cells.foregroundArgb, 0xff070809);
      },
    );

    test('select and next retain final cell after exhaustion', () {
      terminal.write(utf8.encode('ABCDEFGHIJ'));
      bindFirstCell();
      cells.next();
      expect(cells.content, 'B');
      cells.select(5);
      expect(cells.content, 'F');
      expect(cells.next(), isTrue);
      expect(cells.content, 'G');
      cells.select(1);
      expect(cells.next(), isTrue);
      expect(cells.content, 'C');
      cells.select(9);
      expect(cells.next(), isFalse);
      expect(cells.next(), isFalse);
      expect(cells.col, 9);
      expect(cells.content, 'J');
      expect(cells.foregroundArgb, isNull);
    });

    group('select', () {
      test('reads specific column content', () {
        terminal.write(Uint8List.fromList('ABCDE'.codeUnits));
        renderState.update(terminal);
        rows.reset(renderState);
        rows.next();
        cells.reset(rows);

        cells.select(2);
        final result = cells.content;

        expect(result, 'C');
      });

      test('rejects selection after the row advances', () {
        bindFirstCell();
        rows.next();

        expect(() => cells.select(0), throwsA(isA<StateError>()));
      });
    });

    group('dispose', () {
      test('is idempotent', () {
        cells.dispose();

        expect(cells.dispose, returnsNormally);
      });

      test('rejects all operations after disposal', () {
        cells.dispose();

        expect(cells.next, throwsStateError);
        expect(() => cells.col, throwsStateError);
        expect(() => cells.reset(rows), throwsStateError);
        expect(() => cells.select(0), throwsStateError);
      });
    });
  });
}

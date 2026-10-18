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

import 'dart:typed_data' show Uint8List;

import 'package:libghostty/libghostty.dart'
    show
        DirtyState,
        GridRef,
        Position,
        RenderOverscan,
        RenderRowId,
        RenderState,
        RowIterator,
        Selection,
        SemanticPrompt,
        Terminal;
import 'package:test/test.dart';

import '../../helpers/setup.dart';

void main() {
  setUp(() => testEnvironment);

  group('RowIterator', () {
    late Terminal terminal;
    late RenderState renderState;
    late RowIterator rows;

    setUp(() {
      terminal = Terminal(cols: 10, rows: 3);
      renderState = RenderState();
      rows = RowIterator();
    });

    tearDown(() {
      rows.dispose();
      renderState.dispose();
      terminal.dispose();
    });

    group('properties', () {
      test('rejects properties before the first successful next', () {
        renderState.update(terminal);
        rows.reset(renderState);

        expect(() => rows.index, throwsA(isA<StateError>()));
        expect(() => rows.hasStyled, throwsA(isA<StateError>()));
        expect(() => rows.selection, throwsA(isA<StateError>()));
      });

      test('rejects properties after iteration is exhausted', () {
        renderState.update(terminal);
        rows.reset(renderState);
        rows.next();
        rows.next();
        rows.next();

        expect(rows.next(), isFalse);
        expect(() => rows.index, throwsA(isA<StateError>()));
        expect(() => rows.hasStyled, throwsA(isA<StateError>()));
        expect(() => rows.selection, throwsA(isA<StateError>()));
      });

      test('returns content flags for an empty row', () {
        renderState.update(terminal);
        rows.reset(renderState);
        rows.next();

        expect(rows.hasGrapheme, isFalse);
        expect(rows.hasStyled, isFalse);
        expect(rows.hasHyperlink, isFalse);
        expect(rows.hasKittyVirtualPlaceholder, isFalse);
        expect(rows.semanticPrompt, SemanticPrompt.none);
      });

      test('reports styled rows', () {
        terminal.write(Uint8List.fromList('\x1b[1mBold'.codeUnits));
        renderState.update(terminal);
        rows.reset(renderState);
        rows.next();

        final result = rows.hasStyled;

        expect(result, isTrue);
      });

      test('tracks row position', () {
        renderState.update(terminal);
        rows.reset(renderState);
        rows.next();
        final first = rows.index;
        rows.next();

        final second = rows.index;

        expect(first, 0);
        expect(second, 1);
      });

      test(
        'reports viewport positions and stable row ids without overscan',
        () {
          renderState.update(terminal);
          rows.reset(renderState);
          expect(rows.next(), isTrue);
          final firstId = rows.id;

          expect(rows.viewportY, 0);
          expect(
            rows.id == RenderRowId(word0: BigInt.zero, word1: BigInt.zero),
            isFalse,
          );
          renderState.update(terminal);
          rows.reset(renderState);
          expect(rows.next(), isTrue);

          expect(rows.id, firstId);
          expect(rows.viewportY, 0);
        },
      );

      test(
        'reports negative viewport positions for rows above the viewport',
        () {
          terminal.resize(cols: 10, rows: 10);
          terminal.write(
            Uint8List.fromList(
              List.generate(50, (i) => 'line $i').join('\r\n').codeUnits,
            ),
          );
          terminal.scrollViewport(-5);
          renderState.overscanRequest = const RenderOverscan(
            above: 3,
            below: 2,
          );
          renderState.update(terminal);
          rows.reset(renderState);
          final positions = <int>[];
          while (rows.next()) {
            positions.add(rows.viewportY);
          }

          expect(positions, [-3, -2, -1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]);
        },
      );
    });

    void installSelection() {
      terminal.selection = Selection.fromRefs(
        start: GridRef.at(terminal, const Position(row: 1, col: 1)),
        end: GridRef.at(terminal, const Position(row: 1, col: 3)),
      );
    }

    void bindRows() {
      renderState.update(terminal);
      rows.reset(renderState);
    }

    void moveToRow(int row) {
      for (var i = 0; i <= row; i++) {
        expect(rows.next(), isTrue);
      }
    }

    int rowCount() {
      var count = 0;
      rows.reset(renderState);
      while (rows.next()) {
        count++;
      }
      return count;
    }

    group('selection', () {
      test('returns null for an unselected row', () {
        installSelection();
        bindRows();
        moveToRow(0);

        final result = rows.selection;

        expect(result, isNull);
      });

      test('returns row-local selected columns', () {
        installSelection();
        bindRows();
        moveToRow(1);

        final result = rows.selection;

        expect(result, (startCol: 1, endCol: 3));
      });
    });

    group('reset', () {
      test('rewinds iteration', () {
        terminal.write(Uint8List.fromList('Hello'.codeUnits));
        renderState.update(terminal);
        final first = rowCount();

        final second = rowCount();

        expect(second, first);
      });
    });

    group('nextDirty', () {
      test('visits every remaining row when fully dirty', () {
        renderState.update(terminal);
        renderState.clean();
        renderState.dirty = DirtyState.full;
        rows.reset(renderState);

        final indexes = <int>[];
        while (rows.nextDirty()) {
          indexes.add(rows.index);
        }

        expect(indexes, [0, 1, 2]);
      });

      test('skips clean rows and reports the viewport index', () {
        terminal.write(Uint8List.fromList('\x1b[2;1H'.codeUnits));
        renderState.update(terminal);
        renderState.clean();
        terminal.write(Uint8List.fromList('B'.codeUnits));
        renderState.update(terminal);
        rows.reset(renderState);

        final hasRow = rows.nextDirty();

        expect(hasRow, isTrue);
        expect(rows.index, 1);
        expect(rows.nextDirty(), isFalse);
      });
    });

    group('dispose', () {
      test('is idempotent', () {
        rows.dispose();

        expect(rows.dispose, returnsNormally);
      });

      test('rejects all operations after disposal', () {
        rows.dispose();

        expect(rows.next, throwsStateError);
        expect(() => rows.index, throwsStateError);
        expect(() => rows.reset(renderState), throwsStateError);
      });
    });
  });
}

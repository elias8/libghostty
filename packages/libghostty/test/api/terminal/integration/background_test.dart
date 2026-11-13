import 'dart:typed_data';

import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

import '../../../helpers/setup.dart';
import '../helpers/cell_reader.dart';

RgbColor? readBackgroundAt(Terminal terminal, int row, int col) {
  final state = RenderState();
  final rows = RowIterator();
  final cells = CellIterator();
  try {
    state.update(terminal);
    rows.reset(state);
    while (rows.next()) {
      if (rows.index != row) continue;
      cells.reset(rows);
      while (cells.next()) {
        if (cells.col == col) return cells.background;
      }
    }
    throw StateError('Cell ($row, $col) not found');
  } finally {
    cells.dispose();
    rows.dispose();
    state.dispose();
  }
}

void main() {
  setUp(() => testEnvironment);

  group('backgrounds', () {
    late Terminal terminal;

    setUp(() {
      terminal = Terminal(cols: 4, rows: 4);
    });

    tearDown(() {
      terminal.dispose();
    });

    test('erasing cells uses the current background only in the range', () {
      terminal.write(
        Uint8List.fromList(
          '\x1b[48;2;1;2;3mABCD\x1b[1;2H\x1b[48;2;4;5;6m\x1b[2X'.codeUnits,
        ),
      );

      for (final col in [0, 3]) {
        final cell = readCellAt(terminal, 0, col);
        expect(cell.content, col == 0 ? 'A' : 'D');
        expect(readBackgroundAt(terminal, 0, col), const RgbColor(1, 2, 3));
      }
      for (final col in [1, 2]) {
        final cell = readCellAt(terminal, 0, col);
        expect(cell.isEmpty, isTrue);
        expect(readBackgroundAt(terminal, 0, col), const RgbColor(4, 5, 6));
      }
    });

    test(
      'scrolling a region fills the exposed row with the current background',
      () {
        terminal.write(
          Uint8List.fromList(
            'A\r\nB\r\nC\r\nD\x1b[2;3r\x1b[3;1H\x1b[48;2;4;5;6m\n'.codeUnits,
          ),
        );

        expect(readCellAt(terminal, 0, 0).content, 'A');
        expect(readCellAt(terminal, 1, 0).content, 'C');
        expect(readCellAt(terminal, 3, 0).content, 'D');
        for (var col = 0; col < 4; col++) {
          final cell = readCellAt(terminal, 2, col);
          expect(cell.isEmpty, isTrue);
          expect(readBackgroundAt(terminal, 2, col), const RgbColor(4, 5, 6));
        }
      },
    );
  });
}

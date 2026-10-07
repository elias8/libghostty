import 'dart:typed_data';

import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

import '../../helpers/setup.dart';
import 'helpers/cell_reader.dart';

void main() {
  setUp(() => testEnvironment);

  group('RenderState', () {
    late Terminal terminal;
    late RenderState renderState;
    late RowIterator rows;

    setUp(() {
      terminal = Terminal(cols: 80, rows: 24);
      renderState = RenderState();
      rows = RowIterator();
    });

    tearDown(() {
      rows.dispose();
      renderState.dispose();
      terminal.dispose();
    });

    void clearDirty() {
      rows.reset(renderState);
      while (rows.next()) {
        rows.dirty = false;
      }
      renderState.dirty = .clean;
    }

    group('update', () {
      test('reports terminal dimensions', () {
        renderState.update(terminal);

        expect(renderState.cols, 80);
        expect(renderState.rows, 24);
      });

      test('reports dimensions after terminal resize', () {
        terminal.resize(cols: 120, rows: 40);

        renderState.update(terminal);

        expect(renderState.cols, 120);
        expect(renderState.rows, 40);
      });

      test('defaults to no overscan', () {
        expect(
          renderState.overscanRequest,
          const RenderOverscan(above: 0, below: 0),
        );

        renderState.update(terminal);

        expect(renderState.overscan, const RenderOverscan(above: 0, below: 0));
      });

      test('captures requested overscan around the viewport', () {
        terminal.resize(cols: 10, rows: 10);
        terminal.write(
          Uint8List.fromList(
            List.generate(50, (i) => 'line $i').join('\r\n').codeUnits,
          ),
        );
        terminal.scrollViewport(-5);
        renderState.overscanRequest = const RenderOverscan(above: 3, below: 2);

        renderState.update(terminal);

        expect(
          renderState.overscanRequest,
          const RenderOverscan(above: 3, below: 2),
        );
        expect(renderState.overscan, const RenderOverscan(above: 3, below: 2));

        renderState.overscanRequest = const RenderOverscan(above: 0, below: 0);
        expect(renderState.overscan, const RenderOverscan(above: 3, below: 2));
        renderState.update(terminal);

        expect(renderState.overscan, const RenderOverscan(above: 0, below: 0));
      });
    });

    group('dispose', () {
      test('is idempotent', () {
        renderState.dispose();

        expect(renderState.dispose, returnsNormally);
      });

      test('rejects all operations after disposal', () {
        renderState.dispose();

        expect(() => renderState.cols, throwsStateError);
        expect(() => renderState.update(terminal), throwsStateError);
      });
    });

    group('cursor', () {
      test('reports an active cursor in the viewport', () {
        renderState.update(terminal);

        expect(renderState.cursor.viewportHasValue, isTrue);
      });

      test('reports a cursor outside a scrolled viewport', () {
        terminal.resize(cols: 5, rows: 2);
        terminal.write(Uint8List.fromList('one\r\ntwo\r\nthree'.codeUnits));
        terminal.scrollViewport(-1);

        renderState.update(terminal);

        expect(renderState.cursor.viewportHasValue, isFalse);
      });

      test('tracks write position', () {
        terminal.write(Uint8List.fromList('Hi'.codeUnits));

        renderState.update(terminal);

        expect(renderState.cursor.viewportX, 2);
        expect(renderState.cursor.viewportY, 0);
      });

      test('tracks visibility mode', () {
        terminal.write(Uint8List.fromList('\x1b[?25l'.codeUnits));
        renderState.update(terminal);

        expect(renderState.cursor.visible, isFalse);

        terminal.write(Uint8List.fromList('\x1b[?25h'.codeUnits));
        renderState.update(terminal);

        expect(renderState.cursor.visible, isTrue);
      });

      test('uses the default cursor shape for a reset sequence', () {
        terminal.defaultCursorShape = .underline;
        terminal.write(Uint8List.fromList('\x1b[0 q'.codeUnits));

        renderState.update(terminal);

        expect(renderState.cursor.visualStyle, CursorShape.underline);
      });

      test('uses the default cursor blink for a reset sequence', () {
        terminal.defaultCursorBlink = true;
        terminal.write(Uint8List.fromList('\x1b[0 q'.codeUnits));

        renderState.update(terminal);

        expect(renderState.cursor.blinking, isTrue);
      });

      test('reports a normal cursor as not a wide tail', () {
        renderState.update(terminal);

        expect(renderState.cursor.wideTail, isFalse);
      });
    });

    group('dirty', () {
      test('writing content makes the state dirty', () {
        renderState.update(terminal);
        clearDirty();
        terminal.write(Uint8List.fromList('A'.codeUnits));

        renderState.update(terminal);

        expect(renderState.dirty, isNot(DirtyState.clean));
      });

      test('reports partial dirty state for written text', () {
        renderState.update(terminal);
        clearDirty();
        terminal.write(Uint8List.fromList('Hello'.codeUnits));

        renderState.update(terminal);

        expect(renderState.dirty, DirtyState.partial);
      });

      test('reports clean after clearing the dirty state', () {
        terminal.write(Uint8List.fromList('A'.codeUnits));
        renderState.update(terminal);
        clearDirty();

        expect(renderState.dirty, DirtyState.clean);
      });

      test('reports clean after a cursor-only move', () {
        terminal.write(Uint8List.fromList('Hello'.codeUnits));
        renderState.update(terminal);
        clearDirty();
        terminal.write(Uint8List.fromList('\x1b[H'.codeUnits));

        renderState.update(terminal);

        expect(renderState.dirty, DirtyState.clean);
      });

      test('accumulates changes across multiple writes', () {
        renderState.update(terminal);
        clearDirty();
        terminal.write(Uint8List.fromList('X'.codeUnits));
        terminal.write(Uint8List.fromList('\x1b[H'.codeUnits));

        renderState.update(terminal);

        expect(renderState.dirty, isNot(DirtyState.clean));
      });

      test('reports full dirty state after an alternate screen switch', () {
        renderState.update(terminal);
        clearDirty();
        terminal.write(Uint8List.fromList('\x1b[?1049h'.codeUnits));

        renderState.update(terminal);

        expect(renderState.dirty, DirtyState.full);
      });

      test('clean clears global and row dirty state', () {
        terminal.write(Uint8List.fromList('A'.codeUnits));
        renderState.update(terminal);

        renderState.clean();
        rows.reset(renderState);

        expect(renderState.dirty, DirtyState.clean);
        expect(rows.nextDirty(), isFalse);
      });
    });

    group('isRowDirty', () {
      test('reports a written row as dirty', () {
        renderState.update(terminal);
        clearDirty();
        terminal.write(Uint8List.fromList('Hello'.codeUnits));

        renderState.update(terminal);

        expect(isRowDirty(renderState, 0), isTrue);
      });

      test('reports an unwritten row as clean', () {
        renderState.update(terminal);
        clearDirty();
        terminal.write(Uint8List.fromList('Hello'.codeUnits));

        renderState.update(terminal);

        expect(isRowDirty(renderState, 1), isFalse);
      });

      test('clears row dirty state through the row iterator', () {
        terminal.write(Uint8List.fromList('Hello'.codeUnits));
        renderState.update(terminal);
        clearDirty();

        expect(isRowDirty(renderState, 0), isFalse);
      });

      test('tracks multiple dirty rows independently', () {
        renderState.update(terminal);
        clearDirty();
        terminal.write(Uint8List.fromList('Line1\r\nLine2'.codeUnits));

        renderState.update(terminal);

        expect(isRowDirty(renderState, 0), isTrue);
        expect(isRowDirty(renderState, 1), isTrue);
        expect(isRowDirty(renderState, 2), isFalse);
      });

      test('keeps a row clean after a cursor-only move', () {
        terminal.write(Uint8List.fromList('Hello'.codeUnits));
        renderState.update(terminal);
        clearDirty();
        terminal.write(Uint8List.fromList('\x1b[H'.codeUnits));

        renderState.update(terminal);

        expect(isRowDirty(renderState, 0), isFalse);
      });
    });
  });
}

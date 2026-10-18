import 'dart:typed_data' show Uint8List;

import 'package:libghostty/libghostty.dart'
    show CellIterator, RenderState, RowIterator, Terminal;
import 'package:test/test.dart';

import '../../../helpers/setup.dart';

void main() {
  setUp(() => testEnvironment);

  group('borrowed iterator lifetime', () {
    late Terminal terminal;
    late RenderState state;
    late RowIterator rows;
    late CellIterator cells;

    setUp(() {
      terminal = Terminal(cols: 3, rows: 2);
      state = RenderState();
      rows = RowIterator();
      cells = CellIterator();

      terminal.write(Uint8List.fromList('AB\r\nCD'.codeUnits));
      state.update(terminal);

      rows.reset(state);

      expect(rows.next(), isTrue);

      cells.reset(rows);

      expect(cells.next(), isTrue);
      expect(cells.content, 'A');
    });

    tearDown(() {
      cells.dispose();
      rows.dispose();
      state.dispose();
      terminal.dispose();
    });

    Map<String, Object? Function()> cellReads() => {
      'background': () => cells.background,
      'backgroundArgb': () => cells.backgroundArgb,
      'codepoint': () => cells.codepoint,
      'col': () => cells.col,
      'content': () => cells.content,
      'foreground': () => cells.foreground,
      'foregroundArgb': () => cells.foregroundArgb,
      'graphemeLength': () => cells.graphemeLength,
      'hasHyperlink': () => cells.hasHyperlink,
      'hasStyling': () => cells.hasStyling,
      'hasText': () => cells.hasText,
      'isProtected': () => cells.isProtected,
      'isSelected': () => cells.isSelected,
      'semanticContent': () => cells.semanticContent,
      'style': () => cells.style,
      'styleId': () => cells.styleId,
      'wide': () => cells.wide,
    };

    void expectInvalidCells() {
      for (final entry in cellReads().entries) {
        expect(entry.value, throwsStateError, reason: entry.key);
      }
      expect(cells.next, throwsStateError);
      expect(() => cells.select(0), throwsStateError);
    }

    final invalidations = <String, void Function()>{
      'render update': () => state.update(terminal),
      'render disposal': () => state.dispose(),
      'row reset': () => rows.reset(state),
      'row advance': () => expect(rows.next(), isTrue),
      'dirty row advance': () => expect(rows.nextDirty(), isTrue),
      'row exhaustion': () {
        expect(rows.next(), isTrue);
        expect(rows.next(), isFalse);
      },
      'dirty row exhaustion': () {
        expect(rows.nextDirty(), isTrue);
        expect(rows.nextDirty(), isFalse);
      },
      'row disposal': () => rows.dispose(),
      'cell disposal': () => cells.dispose(),
    };

    for (final entry in invalidations.entries) {
      test('rejects every cell read and navigation after ${entry.key}', () {
        for (final read in cellReads().values) {
          read();
        }

        entry.value();

        expectInvalidCells();
      });
    }

    for (final invalidate in ['update', 'render disposal', 'row disposal']) {
      test('rejects row reads and navigation after $invalidate', () {
        switch (invalidate) {
          case 'update':
            state.update(terminal);
          case 'render disposal':
            state.dispose();
          case 'row disposal':
            rows.dispose();
        }
        final reads = <String, Object? Function()>{
          'dirty': () => rows.dirty,
          'hasGrapheme': () => rows.hasGrapheme,
          'hasHyperlink': () => rows.hasHyperlink,
          'hasKittyVirtualPlaceholder': () => rows.hasKittyVirtualPlaceholder,
          'hasStyled': () => rows.hasStyled,
          'index': () => rows.index,
          'viewportY': () => rows.viewportY,
          'id': () => rows.id,
          'selection': () => rows.selection,
          'semanticPrompt': () => rows.semanticPrompt,
          'wrap': () => rows.wrap,
          'wrapContinuation': () => rows.wrapContinuation,
        };
        for (final entry in reads.entries) {
          expect(entry.value, throwsStateError, reason: entry.key);
        }
        expect(() => rows.dirty = false, throwsStateError);
        expect(rows.next, throwsStateError);
        expect(rows.nextDirty, throwsStateError);
      });
    }

    test('validates reset targets before replacing a usable binding', () {
      final unbound = RowIterator();
      final disposed = RenderState()..dispose();
      addTearDown(unbound.dispose);

      expect(() => cells.reset(unbound), throwsStateError);
      expect(cells.content, 'A');

      expect(() => rows.reset(disposed), throwsStateError);
      expect(cells.content, 'A');

      expect(cells.next(), isTrue);
      expect(cells.content, 'B');
    });

    test('can rebind stale cells only to a current positioned row', () {
      state.update(terminal);

      expect(() => cells.reset(rows), throwsStateError);

      rows.reset(state);

      expect(() => cells.reset(rows), throwsStateError);

      expect(rows.next(), isTrue);

      cells.reset(rows);

      expect(cells.next(), isTrue);
      expect(cells.content, 'A');

      cells.select(1);
      expect(cells.content, 'B');
    });

    test('snapshot reads remain valid after terminal disposal', () {
      terminal.dispose();
      expect(cells.content, 'A');
      expect(cells.codepoint, 65);

      expect(cells.next(), isTrue);
      expect(cells.content, 'B');

      expect(rows.next(), isTrue);

      cells.reset(rows);

      expect(cells.next(), isTrue);
      expect(cells.content, 'C');

      expect(() => state.update(terminal), throwsStateError);
      expect(cells.content, 'C');
    });
  });
}

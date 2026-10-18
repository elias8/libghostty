@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:typed_data' show Uint8List;

import 'package:libghostty/libghostty.dart'
    show
        CellIterator,
        OutOfMemoryException,
        PaletteColor,
        RenderState,
        RgbColor,
        RowIterator,
        Style,
        Terminal;
import 'package:test/test.dart';

import '../../../helpers/setup_wasm.dart';

@JS('eval')
external JSAny? _evaluate(JSString source);

@JS('__borrowedArm')
external void _arm(JSString mode);

@JS('__borrowedWatch')
external void _watch();

@JS('__borrowedFaultFired')
external JSNumber _faultFired();

@JS('__borrowedReads')
external JSNumber _reads();

void main() {
  setUpAll(() async {
    _evaluate(
      '''
(() => {
  const instantiate = WebAssembly.instantiate;
  let mode = '', watching = false, reads = 0, faultFired = 0, memory;
  globalThis.__borrowedArm = value => { mode = value; faultFired = 0; };
  globalThis.__borrowedFaultFired = () => faultFired;
  globalThis.__borrowedWatch = () => { reads = 0; watching = true; };
  globalThis.__borrowedReads = () => { watching = false; return reads; };
  for (const name of ['getUint8', 'getUint16', 'getUint32', 'getInt32']) {
    const original = DataView.prototype[name];
    DataView.prototype[name] = function(...args) {
      if (watching && memory && this.buffer === memory.buffer) reads++;
      return original.apply(this, args);
    };
  }
  WebAssembly.instantiate = async (...args) => {
    const result = await instantiate(...args);
    const original = result.instance.exports;
    memory = original.memory;
    const exports = {};
    for (const name of Object.keys(original)) {
      const value = original[name];
      exports[name] = typeof value !== 'function' ? value : (...callArgs) => {
        if (watching && (name.startsWith('ghostty_render_state_row_') ||
            name.startsWith('ghostty_cell_') || name.startsWith('ghostty_row_'))) {
          reads++;
        }
        const value = original[name](...callArgs);
        if (mode === 'style' && name === 'ghostty_render_state_row_cells_get' &&
            callArgs[1] === 2 && value === 0) {
          faultFired++;
          mode = '';
          return -1;
        }
        const fail =
          mode === 'rowInit' && name === 'ghostty_render_state_get' && callArgs[1] === 4 ||
          mode === 'cellInit' && name === 'ghostty_render_state_row_get' && callArgs[1] === 3 ||
          mode === 'cellView' && name === 'ghostty_render_state_row_get' && callArgs[1] === 4 ||
          mode === 'update' && name === 'ghostty_render_state_update' ||
          mode === 'summary' && name === 'ghostty_render_state_get_multi';
        if (fail) { mode = ''; return -1; }
        if (mode === 'shortView' && name === 'ghostty_render_state_row_get' &&
            callArgs[1] === 5 && value === 0) {
          new DataView(memory.buffer).setUint32(callArgs[2] + 4, 1, true);
          faultFired++;
          mode = '';
        }
        if (mode === 'next' && name === 'ghostty_render_state_row_iterator_next' ||
            mode === 'nextDirty' && name === 'ghostty_render_state_row_iterator_next_dirty') {
          mode = '';
          throw new Error('injected failure after native row advancement');
        }
        return value;
      };
    }
    WebAssembly.instantiate = instantiate;
    return {module: result.module, instance: {exports}};
  };
})();
'''
          .toJS,
    );
    await setUpWasm();
  });

  test(
    'retries a failed style lookup without returning the previous style',
    () {
      final terminal = Terminal(cols: 3, rows: 1);
      final state = RenderState();
      final rows = RowIterator();
      final cells = CellIterator();
      addTearDown(() {
        cells.dispose();
        rows.dispose();
        state.dispose();
        terminal.dispose();
      });

      terminal.write(Uint8List.fromList('\x1b[31mA\x1b[32mB'.codeUnits));
      state.update(terminal);

      rows.reset(state);

      expect(rows.next(), isTrue);

      cells.reset(rows);

      expect(cells.next(), isTrue);
      expect(cells.style.foreground, const PaletteColor(1));

      expect(cells.next(), isTrue);

      _arm('style'.toJS);
      expect(() => cells.style, throwsA(isA<OutOfMemoryException>()));
      expect(_faultFired().toDartInt, 1);
      expect(cells.style.foreground, const PaletteColor(2));
    },
  );

  for (final packed in [false, true]) {
    test(
      'clears stale RGB background on raw decode fallback, packed=$packed',
      () {
        final terminal = Terminal(cols: 3, rows: 1);
        final state = RenderState();
        final rows = RowIterator();
        final cells = CellIterator();
        addTearDown(() {
          cells.dispose();
          rows.dispose();
          state.dispose();
          terminal.dispose();
        });

        terminal.write(
          Uint8List.fromList(
            '\x1b[48;2;255;128;0m\x1b[1X\x1b[0m\x1b[2GX'.codeUnits,
          ),
        );
        state.update(terminal);
        rows.reset(state);
        expect(rows.next(), isTrue);

        _arm('shortView'.toJS);

        cells.reset(rows);
        expect(_faultFired().toDartInt, 1);
        expect(cells.next(), isTrue);
        expect(cells.hasText, isFalse);
        expect(cells.styleId, 0);
        expect(cells.style, const Style());
        if (packed) {
          expect(cells.backgroundArgb, 0xFFFF8000);
        } else {
          expect(cells.background, const RgbColor(255, 128, 0));
        }
        expect(cells.next(), isTrue);
        if (packed) {
          expect(cells.backgroundArgb, isNull);
        } else {
          expect(cells.background, isNull);
        }
        expect(cells.codepoint, 'X'.codeUnitAt(0));
      },
    );
  }

  for (final mode in [
    'rowInit',
    'cellInit',
    'cellView',
    'next',
    'nextDirty',
    'update',
    'summary',
  ]) {
    test('rejects borrowed reads after a mutating $mode failure', () {
      final terminal = Terminal(cols: 3, rows: 2);
      final state = RenderState();
      final rows = RowIterator();
      final cells = CellIterator();
      addTearDown(() {
        cells.dispose();
        rows.dispose();
        state.dispose();
        terminal.dispose();
      });

      terminal.write(Uint8List.fromList('AB\r\nCD'.codeUnits));
      state.update(terminal);

      rows.reset(state);

      expect(rows.next(), isTrue);

      cells.reset(rows);

      expect(cells.next(), isTrue);

      _watch();
      expect(cells.content, 'A');
      expect(_reads().toDartInt, greaterThan(0));

      _arm(mode.toJS);
      final void Function() mutate = switch (mode) {
        'rowInit' => () => rows.reset(state),
        'cellInit' || 'cellView' => () => cells.reset(rows),
        'next' => rows.next,
        'nextDirty' => rows.nextDirty,
        _ => () => state.update(terminal),
      };
      expect(
        mutate,
        mode == 'next' || mode == 'nextDirty'
            ? throwsA(
                predicate<Object>(
                  (error) => error.toString().contains(
                    'injected failure after native row advancement',
                  ),
                ),
              )
            : throwsA(isA<OutOfMemoryException>()),
      );

      _watch();
      final cellReads = <Object? Function()>[
        () => cells.background,
        () => cells.backgroundArgb,
        () => cells.codepoint,
        () => cells.col,
        () => cells.content,
        () => cells.foreground,
        () => cells.foregroundArgb,
        () => cells.graphemeLength,
        () => cells.hasHyperlink,
        () => cells.hasStyling,
        () => cells.hasText,
        () => cells.isProtected,
        () => cells.isSelected,
        () => cells.semanticContent,
        () => cells.style,
        () => cells.styleId,
        () => cells.wide,
      ];
      for (final read in cellReads) {
        expect(read, throwsStateError);
      }
      expect(cells.next, throwsStateError);
      expect(() => cells.select(0), throwsStateError);
      if (mode == 'rowInit' ||
          mode == 'next' ||
          mode == 'nextDirty' ||
          mode == 'update' ||
          mode == 'summary') {
        expect(() => rows.index, throwsStateError);
        expect(rows.next, throwsStateError);
        expect(rows.nextDirty, throwsStateError);
        expect(() => cells.reset(rows), throwsStateError);
      }
      expect(_reads().toDartInt, 0);

      rows.reset(state);

      expect(rows.next(), isTrue);
      expect(rows.index, 0);

      cells.reset(rows);

      expect(cells.next(), isTrue);
      expect(cells.content, 'A');
    });
  }
}

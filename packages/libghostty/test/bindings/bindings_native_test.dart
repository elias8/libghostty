@Tags(['ffi'])
library;

import 'dart:typed_data';

import 'package:libghostty/src/bindings/bindings.dart';
import 'package:test/test.dart';

void main() {
  group('native terminal bindings', () {
    late int handle;

    setUp(() {
      handle = bindings.terminalNew(80, 24);
    });

    tearDown(() {
      bindings.terminalFree(handle);
    });

    test('create and free terminal', () {
      expect(handle, isNonZero);
    });

    test('render state dimensions match creation', () {
      bindings.renderStateUpdate(handle);
      expect(bindings.renderStateGetCols(handle), 80);
      expect(bindings.renderStateGetRows(handle), 24);
    });

    test('initial cursor is at origin and visible', () {
      bindings.renderStateUpdate(handle);
      expect(bindings.renderStateGetCursorX(handle), 0);
      expect(bindings.renderStateGetCursorY(handle), 0);
      expect(bindings.renderStateGetCursorVisible(handle), isTrue);
    });

    test('write bytes and read viewport', () {
      bindings.terminalWrite(handle, Uint8List.fromList('Hello'.codeUnits));
      bindings.renderStateUpdate(handle);

      final cells = bindings.renderStateGetViewport(handle, 80, 24);
      expect(cells.length, 80 * 24);

      expect(cells[0].codepoint, 'H'.codeUnitAt(0));
      expect(cells[1].codepoint, 'e'.codeUnitAt(0));
      expect(cells[2].codepoint, 'l'.codeUnitAt(0));
      expect(cells[3].codepoint, 'l'.codeUnitAt(0));
      expect(cells[4].codepoint, 'o'.codeUnitAt(0));
      expect(cells[5].codepoint, 0);
    });

    test('cursor moves after write', () {
      bindings.terminalWrite(handle, Uint8List.fromList('ABC'.codeUnits));
      bindings.renderStateUpdate(handle);
      expect(bindings.renderStateGetCursorX(handle), 3);
      expect(bindings.renderStateGetCursorY(handle), 0);
    });

    test('resize changes dimensions', () {
      bindings.terminalResize(handle, 40, 10);
      bindings.renderStateUpdate(handle);
      expect(bindings.renderStateGetCols(handle), 40);
      expect(bindings.renderStateGetRows(handle), 10);
    });

    test('bell count incremented by BEL character', () {
      expect(bindings.terminalGetBellCount(handle), 0);
      bindings.terminalWrite(handle, Uint8List.fromList([0x07]));
      expect(bindings.terminalGetBellCount(handle), 1);
      bindings.terminalResetBellCount(handle);
      expect(bindings.terminalGetBellCount(handle), 0);
    });

    test('title change via OSC 0', () {
      expect(bindings.terminalHasTitleChanged(handle), isFalse);
      const osc = '\x1b]0;My Title\x07';
      bindings.terminalWrite(handle, Uint8List.fromList(osc.codeUnits));
      expect(bindings.terminalHasTitleChanged(handle), isTrue);
      expect(bindings.terminalGetTitle(handle), 'My Title');
      expect(bindings.terminalHasTitleChanged(handle), isFalse);
    });

    test('alternate screen mode', () {
      expect(bindings.terminalIsAlternateScreen(handle), isFalse);
      const enterAlt = '\x1b[?1049h';
      bindings.terminalWrite(handle, Uint8List.fromList(enterAlt.codeUnits));
      expect(bindings.terminalIsAlternateScreen(handle), isTrue);
      const exitAlt = '\x1b[?1049l';
      bindings.terminalWrite(handle, Uint8List.fromList(exitAlt.codeUnits));
      expect(bindings.terminalIsAlternateScreen(handle), isFalse);
    });

    test('bold attribute sets flag', () {
      const boldHello = '\x1b[1mHi';
      bindings.terminalWrite(handle, Uint8List.fromList(boldHello.codeUnits));
      bindings.renderStateUpdate(handle);
      final cells = bindings.renderStateGetViewport(handle, 80, 24);
      expect(cells[0].flags & 1, 1);
      expect(cells[0].codepoint, 'H'.codeUnitAt(0));
    });

    test('create with config sets colors', () {
      const config = RawTerminalConfig(
        fgR: 255,
        fgG: 128,
        fgB: 64,
        fgSet: true,
        bgR: 10,
        bgG: 20,
        bgB: 30,
        bgSet: true,
      );
      final h = bindings.terminalNewWithConfig(80, 24, config);
      try {
        bindings.renderStateUpdate(h);
        final fg = bindings.renderStateGetFgColor(h);
        expect((fg >> 16) & 0xFF, 255);
        expect((fg >> 8) & 0xFF, 128);
        expect(fg & 0xFF, 64);

        final bg = bindings.renderStateGetBgColor(h);
        expect((bg >> 16) & 0xFF, 10);
        expect((bg >> 8) & 0xFF, 20);
        expect(bg & 0xFF, 30);
      } finally {
        bindings.terminalFree(h);
      }
    });

    test('dirty tracking works', () {
      bindings.renderStateUpdate(handle);
      bindings.renderStateMarkClean(handle);

      bindings.terminalWrite(handle, Uint8List.fromList('X'.codeUnits));
      final dirty = bindings.renderStateUpdate(handle);
      expect(dirty, greaterThan(0));
    });

    test('scrollback grows when lines scroll off', () {
      expect(bindings.terminalGetScrollbackLength(handle), 0);

      final lines = List.generate(30, (i) => 'Line $i\n').join();
      bindings.terminalWrite(handle, Uint8List.fromList(lines.codeUnits));

      final scrollback = bindings.terminalGetScrollbackLength(handle);
      expect(scrollback, greaterThan(0));
    });

    test('scrollback line returns cells', () {
      final lines = List.generate(30, (i) => 'L$i\n').join();
      bindings.terminalWrite(handle, Uint8List.fromList(lines.codeUnits));

      final scrollback = bindings.terminalGetScrollbackLength(handle);
      if (scrollback > 0) {
        final line = bindings.terminalGetScrollbackLine(handle, 0, 80);
        expect(line, isNotNull);
        expect(line!.length, 80);
        expect(line[0].codepoint, 'L'.codeUnitAt(0));
      }
    });
  });
}

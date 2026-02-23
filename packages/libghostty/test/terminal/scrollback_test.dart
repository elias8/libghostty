@Tags(['ffi'])
library;

import 'dart:typed_data';

import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

void main() {
  group('Scrollback', () {
    test('fill screen plus one line creates scrollback', () {
      final terminal = Terminal(cols: 80, rows: 5);
      for (var i = 0; i < 6; i++) {
        terminal.write(Uint8List.fromList('Line$i\r\n'.codeUnits));
      }
      expect(terminal.scrollback.length, greaterThan(0));
      terminal.dispose();
    });

    test('scrollback preserves content', () {
      final terminal = Terminal(cols: 80, rows: 3);
      terminal.write(
        Uint8List.fromList('AAA\r\nBBB\r\nCCC\r\nDDD\r\n'.codeUnits),
      );
      expect(terminal.scrollback.length, greaterThan(0));
      final firstLine = terminal.scrollback.lineAt(0);
      expect(firstLine.text, startsWith('AAA'));
      terminal.dispose();
    });

    test('scrollback grows with output', () {
      final terminal = Terminal(cols: 80, rows: 3);
      for (var i = 0; i < 20; i++) {
        terminal.write(Uint8List.fromList('Line$i\r\n'.codeUnits));
      }
      expect(terminal.scrollback.length, greaterThan(0));
      expect(terminal.scrollback.length, lessThan(20));
      terminal.dispose();
    });

    test('alternate screen has no scrollback', () {
      final terminal = Terminal(cols: 80, rows: 3);
      terminal.write(Uint8List.fromList('\x1b[?1049h'.codeUnits));
      final initialLength = terminal.scrollback.length;
      for (var i = 0; i < 10; i++) {
        terminal.write(Uint8List.fromList('AltLine$i\r\n'.codeUnits));
      }
      expect(terminal.scrollback.length, initialLength);
      terminal.dispose();
    });

    test('scrollback lineAt returns correct line', () {
      final terminal = Terminal(cols: 10, rows: 2);
      terminal.write(
        Uint8List.fromList('FIRST\r\nSECOND\r\nTHIRD\r\n'.codeUnits),
      );
      expect(terminal.scrollback.length, greaterThanOrEqualTo(1));
      terminal.dispose();
    });

    test('lineAt throws for out-of-bounds index', () {
      final terminal = Terminal(cols: 80, rows: 5);
      terminal.write(Uint8List.fromList('Line0\r\n'.codeUnits));
      expect(() => terminal.scrollback.lineAt(-1), throwsRangeError);
      expect(
        () => terminal.scrollback.lineAt(terminal.scrollback.length),
        throwsRangeError,
      );
      terminal.dispose();
    });
  });
}

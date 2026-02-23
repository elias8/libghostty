@Tags(['ffi'])
library;

import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

void main() {
  group('Scrollback', () {
    late Terminal terminal;

    setUp(() {
      terminal = Terminal(cols: 80, rows: 5);
    });

    tearDown(() {
      terminal.dispose();
    });

    test('fill screen plus one line creates scrollback', () {
      for (var i = 0; i < 6; i++) {
        terminal.write(.fromList('Line$i\r\n'.codeUnits));
      }
      expect(terminal.scrollback.length, greaterThan(0));
    });

    test('scrollback preserves content', () {
      final t = Terminal(cols: 80, rows: 3);
      addTearDown(t.dispose);
      t.write(.fromList('AAA\r\nBBB\r\nCCC\r\nDDD\r\n'.codeUnits));
      expect(t.scrollback.length, greaterThan(0));
      final firstLine = t.scrollback.lineAt(0);
      expect(firstLine.text, startsWith('AAA'));
    });

    test('scrollback grows with output', () {
      final t = Terminal(cols: 80, rows: 3);
      addTearDown(t.dispose);
      for (var i = 0; i < 20; i++) {
        t.write(.fromList('Line$i\r\n'.codeUnits));
      }
      expect(t.scrollback.length, greaterThan(0));
      expect(t.scrollback.length, lessThan(20));
    });

    test('alternate screen has no scrollback', () {
      terminal.write(.fromList('\x1b[?1049h'.codeUnits));
      final initialLength = terminal.scrollback.length;
      for (var i = 0; i < 10; i++) {
        terminal.write(.fromList('AltLine$i\r\n'.codeUnits));
      }
      expect(terminal.scrollback.length, initialLength);
    });

    test('lineAt returns correct line content', () {
      final t = Terminal(cols: 10, rows: 2);
      addTearDown(t.dispose);
      t.write(.fromList('FIRST\r\nSECOND\r\nTHIRD\r\n'.codeUnits));
      expect(t.scrollback.length, greaterThanOrEqualTo(1));
      expect(t.scrollback.lineAt(0).text, startsWith('FIRST'));
    });

    test('lineAt throws for out-of-bounds index', () {
      terminal.write(.fromList('Line0\r\n'.codeUnits));
      expect(() => terminal.scrollback.lineAt(-1), throwsRangeError);
      expect(
        () => terminal.scrollback.lineAt(terminal.scrollback.length),
        throwsRangeError,
      );
    });
  });
}

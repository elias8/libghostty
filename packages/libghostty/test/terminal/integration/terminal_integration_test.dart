@Tags(['ffi'])
library;

import 'dart:typed_data';

import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

void main() {
  group('Terminal integration', () {
    late Terminal terminal;

    setUp(() {
      terminal = Terminal(cols: 80, rows: 24);
    });

    tearDown(() {
      terminal.dispose();
    });

    test('colored ls-like output', () {
      // Simulate: bold blue "dir/", then reset, then "file.txt"
      terminal.write(
        Uint8List.fromList('\x1b[1;34mdir/\x1b[0m  file.txt'.codeUnits),
      );

      final dirCell = terminal.screen.cellAt(0, 0);
      expect(dirCell.content, 'd');
      expect(dirCell.style.bold, isTrue);
      expect(dirCell.foreground, isA<RgbColor>());

      final fileCell = terminal.screen.cellAt(0, 6);
      expect(fileCell.content, 'f');
      expect(fileCell.style.bold, isFalse);
      // After reset, foreground returns to default
      expect(fileCell.foreground, isA<DefaultColor>());
    });

    test('cursor movement sequence', () {
      terminal.write(Uint8List.fromList('ABCDE'.codeUnits));
      terminal.write(
        Uint8List.fromList('\x1b[1;3H'.codeUnits),
      ); // Move to (1,3)
      terminal.write(Uint8List.fromList('X'.codeUnits));
      expect(terminal.screen.cellAt(0, 2).content, 'X');
      expect(terminal.screen.cellAt(0, 0).content, 'A');
      expect(terminal.screen.cellAt(0, 1).content, 'B');
    });

    test('erase display below cursor', () {
      terminal.write(Uint8List.fromList('Line1\r\nLine2\r\nLine3'.codeUnits));
      terminal.write(Uint8List.fromList('\x1b[2;1H'.codeUnits));
      terminal.write(Uint8List.fromList('\x1b[0J'.codeUnits));
      expect(terminal.screen.cellAt(0, 0).content, 'L');
      expect(terminal.screen.cellAt(1, 0), Cell.empty);
      expect(terminal.screen.cellAt(2, 0), Cell.empty);
    });

    test('scroll region', () {
      for (var i = 0; i < 5; i++) {
        terminal.write(Uint8List.fromList('Row$i\r\n'.codeUnits));
      }
      terminal.write(Uint8List.fromList('\x1b[2;4r'.codeUnits));
      terminal.write(Uint8List.fromList('\x1b[2;1H'.codeUnits));
      terminal.write(Uint8List.fromList('\x1b[S'.codeUnits));
      expect(terminal.screen.cellAt(0, 0).content, 'R');
    });

    test('256-color and RGB colors', () {
      terminal.write(
        Uint8List.fromList(
          '\x1b[38;5;196mRed\x1b[38;2;0;255;0mGreen'.codeUnits,
        ),
      );
      final redCell = terminal.screen.cellAt(0, 0);
      expect(redCell.foreground, isA<RgbColor>());

      final greenCell = terminal.screen.cellAt(0, 3);
      expect(greenCell.foreground, const RgbColor(0, 255, 0));
    });

    test('CellColor pattern matching', () {
      terminal.write(Uint8List.fromList('\x1b[38;2;100;150;200mA'.codeUnits));
      final cell = terminal.screen.cellAt(0, 0);
      final result = switch (cell.foreground) {
        DefaultColor() => 'default',
        PaletteColor(index: final i) => 'palette:$i',
        RgbColor(:final r, :final g, :final b) => 'rgb:$r,$g,$b',
      };
      expect(result, 'rgb:100,150,200');
    });

    test('title change via OSC', () {
      String? title;
      terminal.onTitleChanged.listen((t) => title = t);
      terminal.write(
        Uint8List.fromList('\x1b]0;My Terminal Title\x07'.codeUnits),
      );
      expect(title, 'My Terminal Title');
    });

    test('bell notification', () {
      var bellCount = 0;
      terminal.onBell.listen((_) => bellCount++);
      terminal.write(Uint8List.fromList([0x07, 0x07, 0x07]));
      expect(bellCount, 3);
    });

    test('bracketed paste mode toggle', () {
      terminal.write(Uint8List.fromList('\x1b[?2004h'.codeUnits));
      expect(terminal.modes.bracketedPaste, isTrue);
      terminal.write(Uint8List.fromList('\x1b[?2004l'.codeUnits));
      expect(terminal.modes.bracketedPaste, isFalse);
    });

    test('alternate screen preserves primary', () {
      terminal.write(Uint8List.fromList('Primary content'.codeUnits));
      terminal.write(Uint8List.fromList('\x1b[?1049h'.codeUnits));
      terminal.write(Uint8List.fromList('Alternate content'.codeUnits));
      terminal.write(Uint8List.fromList('\x1b[?1049l'.codeUnits));
      expect(terminal.screen.cellAt(0, 0).content, 'P');
    });

    test('resize preserves visible content', () {
      terminal.write(Uint8List.fromList('Hello'.codeUnits));
      terminal.resize(cols: 120, rows: 40);
      expect(terminal.screen.cellAt(0, 0).content, 'H');
      expect(terminal.screen.cols, 120);
      expect(terminal.screen.rows, 40);
    });

    test('scrollback captures history', () {
      final terminal = Terminal(cols: 80, rows: 3);
      for (var i = 0; i < 10; i++) {
        terminal.write(Uint8List.fromList('Line$i\r\n'.codeUnits));
      }
      expect(terminal.scrollback.length, greaterThan(0));
      terminal.dispose();
    });

    test('multiple style attributes combine', () {
      terminal.write(Uint8List.fromList('\x1b[1;3;4;31;42mStyled'.codeUnits));
      final cell = terminal.screen.cellAt(0, 0);
      expect(cell.style.bold, isTrue);
      expect(cell.style.italic, isTrue);
      expect(cell.style.underline, UnderlineStyle.single);
      expect(cell.foreground, isA<RgbColor>());
      expect(cell.background, isA<RgbColor>());
    });

    test('line wrapping at terminal width', () {
      final longLine = 'X' * 85;
      terminal.write(Uint8List.fromList(longLine.codeUnits));
      expect(terminal.screen.cellAt(0, 79).content, 'X');
      expect(terminal.screen.cellAt(1, 0).content, 'X');
      expect(terminal.cursor.row, 1);
    });

    test('multi-byte UTF-8 rendering', () {
      terminal.write(Uint8List.fromList([0xC3, 0xA9])); // é
      terminal.write(Uint8List.fromList([0xE2, 0x9C, 0x93])); // ✓
      expect(terminal.screen.cellAt(0, 0).content, '\u00E9');
      expect(terminal.screen.cellAt(0, 1).content, '\u2713');
    });

    test('complete terminal session simulation', () {
      final events = <String>[];
      terminal.onTitleChanged.listen((t) => events.add('title:$t'));
      terminal.onBell.listen((_) => events.add('bell'));

      terminal.write(Uint8List.fromList('\x1b]0;bash\x07'.codeUnits));
      terminal.write(Uint8List.fromList('\$ ls\r\n'.codeUnits));
      terminal.write(
        Uint8List.fromList('\x1b[1;34mdir/\x1b[0m  file.txt\r\n'.codeUnits),
      );
      terminal.write(Uint8List.fromList(r'$ '.codeUnits));
      terminal.write(Uint8List.fromList('\x07'.codeUnits));

      expect(events, contains('title:bash'));
      expect(events, contains('bell'));
      expect(terminal.screen.lineAt(1).text, contains('dir/'));
    });
  });
}

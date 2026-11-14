import 'dart:typed_data';

import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

import '../../../helpers/setup.dart';
import '../helpers/cell_reader.dart';

void main() {
  setUp(() => testEnvironment);

  group('Terminal', () {
    late Terminal terminal;

    setUp(() {
      terminal = Terminal(cols: 80, rows: 24);
    });

    tearDown(() {
      terminal.dispose();
    });

    group('integration', () {
      test('renders colored ls-like output', () {
        terminal.write(
          Uint8List.fromList('\x1b[1;34mdir/\x1b[0m  file.txt'.codeUnits),
        );

        final dirCell = readCellAt(terminal, 0, 0);
        expect(dirCell.content, 'd');
        expect(dirCell.style.bold, isTrue);
        expect(dirCell.foreground, isA<PaletteColor>());

        final fileCell = readCellAt(terminal, 0, 6);
        expect(fileCell.content, 'f');
        expect(fileCell.style.bold, isFalse);
        expect(fileCell.foreground, isA<DefaultColor>());
      });

      test('CUP overwrites mid-line content', () {
        terminal.write(Uint8List.fromList('ABCDE'.codeUnits));
        terminal.write(Uint8List.fromList('\x1b[1;3H'.codeUnits));
        terminal.write(Uint8List.fromList('X'.codeUnits));
        final cellX = readCellAt(terminal, 0, 2);
        expect(cellX.content, 'X');
        final cellA = readCellAt(terminal, 0, 0);
        expect(cellA.content, 'A');
        final cellB = readCellAt(terminal, 0, 1);
        expect(cellB.content, 'B');
      });

      test('erase display clears below cursor', () {
        terminal.write(Uint8List.fromList('Line1\r\nLine2\r\nLine3'.codeUnits));
        terminal.write(Uint8List.fromList('\x1b[2;1H'.codeUnits));
        terminal.write(Uint8List.fromList('\x1b[0J'.codeUnits));
        final cell00 = readCellAt(terminal, 0, 0);
        expect(cell00.content, 'L');
        final cell10 = readCellAt(terminal, 1, 0);
        expect(cell10.isEmpty, isTrue);
        final cell20 = readCellAt(terminal, 2, 0);
        expect(cell20.isEmpty, isTrue);
      });

      test('scroll region preserves content outside region', () {
        terminal.write(
          Uint8List.fromList(
            'Row0\r\nRow1\r\nRow2\r\nRow3\r\nRow4\r\n'.codeUnits,
          ),
        );
        terminal.write(Uint8List.fromList('\x1b[2;4r'.codeUnits));
        terminal.write(Uint8List.fromList('\x1b[2;1H'.codeUnits));
        terminal.write(Uint8List.fromList('\x1b[S'.codeUnits));
        final cell00 = readCellAt(terminal, 0, 0);
        expect(cell00.content, 'R');
      });

      test('renders 256-color and RGB foreground colors', () {
        terminal.write(
          Uint8List.fromList(
            '\x1b[38;5;196mRed\x1b[38;2;0;255;0mGreen'.codeUnits,
          ),
        );
        final redCell = readCellAt(terminal, 0, 0);
        expect(redCell.foreground, isA<PaletteColor>());

        final greenCell = readCellAt(terminal, 0, 3);
        expect(greenCell.foreground, const RgbColor(0, 255, 0));
      });

      test('renders RGB foreground as RgbColor', () {
        terminal.write(Uint8List.fromList('\x1b[38;2;100;150;200mA'.codeUnits));
        final cell = readCellAt(terminal, 0, 0);
        expect(cell.foreground, const RgbColor(100, 150, 200));
      });

      test('combines multiple style attributes', () {
        terminal.write(Uint8List.fromList('\x1b[1;3;4;31;42mStyled'.codeUnits));
        final cell = readCellAt(terminal, 0, 0);
        expect(cell.style.bold, isTrue);
        expect(cell.style.italic, isTrue);
        expect(cell.underlineStyle, SgrUnderline.single);
        expect(cell.foreground, isA<PaletteColor>());
        expect(cell.background, isA<PaletteColor>());
      });

      test('applies OSC 8 hyperlink to linked cells', () {
        terminal.write(
          Uint8List.fromList(
            '\x1b]8;;https://example.com\x1b\\Click\x1b]8;;\x1b\\'.codeUnits,
          ),
        );

        final linked = readCellAt(terminal, 0, 0);
        expect(linked.content, 'C');
        expect(linked.hasHyperlink, isTrue);

        final lastLinked = readCellAt(terminal, 0, 4);
        expect(lastLinked.content, 'k');
        expect(lastLinked.hasHyperlink, isTrue);

        final after = readCellAt(terminal, 0, 5);
        expect(after.hasHyperlink, isFalse);
      });
    });
  });
}

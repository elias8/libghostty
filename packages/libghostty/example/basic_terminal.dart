// ignore_for_file: avoid_print

import 'dart:typed_data';

import 'package:libghostty/libghostty.dart';

void main() {
  final terminal = Terminal(cols: 80, rows: 24);

  terminal.write(
    Uint8List.fromList(
      '\x1b[1;34mHello\x1b[0m, \x1b[32mWorld\x1b[0m!\r\n'.codeUnits,
    ),
  );

  final screen = terminal.screen;
  for (var row = 0; row < screen.rows; row++) {
    final text = screen.lineAt(row).text;
    if (text.isNotEmpty) print('Row $row: $text');
  }

  final cell = screen.cellAt(0, 0);
  print('\nFirst cell: "${cell.content}", bold: ${cell.style.bold}');

  terminal.dispose();
}

// ignore_for_file: avoid_print

import 'dart:typed_data';

import 'package:libghostty/libghostty.dart';

void main() {
  final terminal = Terminal(cols: 80, rows: 24);

  final logLines = [
    '\x1b[32m[INFO]\x1b[0m  Application started',
    '\x1b[33m[WARN]\x1b[0m  Config not found, using defaults',
    '\x1b[31m[ERROR]\x1b[0m Database unreachable',
  ];

  for (final line in logLines) {
    terminal.write(Uint8List.fromList('$line\r\n'.codeUnits));
  }

  for (var row = 0; row < terminal.screen.rows; row++) {
    final text = terminal.screen.lineAt(row).text;
    if (text.isEmpty) break;

    final color = switch (terminal.screen.cellAt(row, 0).foreground) {
      PaletteColor(index: 2) => 'GREEN',
      PaletteColor(index: 3) => 'YELLOW',
      PaletteColor(index: 1) => 'RED',
      _ => 'DEFAULT',
    };

    print('[$color] $text');
  }

  terminal.dispose();
}

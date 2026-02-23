// ignore_for_file: avoid_print

import 'dart:typed_data';

import 'package:libghostty/libghostty.dart';

void main() {
  final terminal = Terminal(cols: 80, rows: 24);

  terminal.onTitleChanged.listen((title) => print('Title: $title'));
  terminal.onBell.listen((_) => print('Bell!'));

  terminal.write(.fromList('\x1b]0;Tab Name\x07'.codeUnits));
  terminal.write(.fromList('Hello\x07'.codeUnits));

  print('Bracketed paste: ${terminal.modes.bracketedPaste}');
  terminal.write(Uint8List.fromList('\x1b[?2004h'.codeUnits));
  print('Bracketed paste: ${terminal.modes.bracketedPaste}');

  terminal.dispose();
}

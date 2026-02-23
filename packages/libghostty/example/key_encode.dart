// ignore_for_file: avoid_print

import 'package:libghostty/input.dart';

void main() {
  final encoder = KeyEncoder();
  final event = KeyEvent()
    ..action = KeyAction.press
    ..key = Key.keyC
    ..mods = Mods.ctrl;

  final sequence = encoder.encode(event);
  print('Ctrl+C encodes to: ${sequence.codeUnits}'); // [3] (ETX)

  event.key = Key.arrowUp;
  event.mods = Mods.none;
  print('Arrow Up encodes to: ${encoder.encode(event).codeUnits}');

  event.dispose();
  encoder.dispose();
}

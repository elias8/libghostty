// ignore_for_file: avoid_print

import 'package:libghostty/parsing.dart';

void main() {
  final parser = SgrParser();

  final attrs = parser.parse([1, 31]);
  for (final attr in attrs) {
    switch (attr) {
      case SgrBold():
        print('Bold');
      case SgrForeground8(:final index):
        print('Foreground color: $index');
      default:
        print(attr.runtimeType);
    }
  }

  parser.dispose();
}

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty_flutter/src/rendering/color_run.dart';

void main() {
  group('ColorRun', () {
    test('stores startCol, endCol, and color', () {
      const run = ColorRun(3, 7, Color(0xFFFF0000));
      expect(run.startCol, 3);
      expect(run.endCol, 7);
      expect(run.color, const Color(0xFFFF0000));
    });

    test('span is endCol minus startCol', () {
      const run = ColorRun(2, 5, Color(0xFF000000));
      expect(run.endCol - run.startCol, 3);
    });
  });
}

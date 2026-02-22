import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

void main() {
  group('RgbColor', () {
    test('constructor stores components', () {
      const color = RgbColor(10, 20, 30);
      expect(color.r, 10);
      expect(color.g, 20);
      expect(color.b, 30);
    });

    test('equality with same values', () {
      const a = RgbColor(100, 150, 200);
      const b = RgbColor(100, 150, 200);
      expect(a, equals(b));
    });

    test('inequality with different values', () {
      const a = RgbColor(100, 150, 200);
      const b = RgbColor(100, 150, 201);
      expect(a, isNot(equals(b)));
    });

    test('hashCode is consistent with equality', () {
      const a = RgbColor(50, 100, 150);
      const b = RgbColor(50, 100, 150);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('black (0,0,0)', () {
      const black = RgbColor(0, 0, 0);
      expect(black.r, 0);
      expect(black.g, 0);
      expect(black.b, 0);
    });

    test('white (255,255,255)', () {
      const white = RgbColor(255, 255, 255);
      expect(white.r, 255);
      expect(white.g, 255);
      expect(white.b, 255);
    });

    test('toString contains components', () {
      const color = RgbColor(10, 20, 30);
      expect(color.toString(), 'RgbColor(10, 20, 30)');
    });
  });

  group('NamedColor', () {
    test('standard colors have expected indices', () {
      expect(NamedColor.black, 0);
      expect(NamedColor.red, 1);
      expect(NamedColor.green, 2);
      expect(NamedColor.yellow, 3);
      expect(NamedColor.blue, 4);
      expect(NamedColor.magenta, 5);
      expect(NamedColor.cyan, 6);
      expect(NamedColor.white, 7);
    });

    test('bright colors have expected indices', () {
      expect(NamedColor.brightBlack, 8);
      expect(NamedColor.brightRed, 9);
      expect(NamedColor.brightGreen, 10);
      expect(NamedColor.brightYellow, 11);
      expect(NamedColor.brightBlue, 12);
      expect(NamedColor.brightMagenta, 13);
      expect(NamedColor.brightCyan, 14);
      expect(NamedColor.brightWhite, 15);
    });
  });
}

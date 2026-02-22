import 'package:libghostty/input.dart';
import 'package:test/test.dart';

void main() {
  group('Mods', () {
    test('none has value 0', () {
      expect(Mods.none.value, 0);
      expect(Mods.none.isEmpty, isTrue);
    });

    test('named constants have correct bit values', () {
      expect(Mods.shift.value, 1 << 0);
      expect(Mods.ctrl.value, 1 << 1);
      expect(Mods.alt.value, 1 << 2);
      expect(Mods.superKey.value, 1 << 3);
      expect(Mods.capsLock.value, 1 << 4);
      expect(Mods.numLock.value, 1 << 5);
    });

    test('side constants have correct bit values', () {
      expect(Mods.shiftSide.value, 1 << 6);
      expect(Mods.ctrlSide.value, 1 << 7);
      expect(Mods.altSide.value, 1 << 8);
      expect(Mods.superSide.value, 1 << 9);
    });

    test('| operator combines flags', () {
      final combined = Mods.ctrl | Mods.shift;
      expect(combined.hasCtrl, isTrue);
      expect(combined.hasShift, isTrue);
      expect(combined.hasAlt, isFalse);
    });

    test('& operator masks flags', () {
      final combined = Mods.ctrl | Mods.shift | Mods.alt;
      final masked = combined & Mods.ctrl;
      expect(masked.hasCtrl, isTrue);
      expect(masked.hasShift, isFalse);
      expect(masked.hasAlt, isFalse);
    });

    test('has* getters return correct results for each flag', () {
      expect(Mods.shift.hasShift, isTrue);
      expect(Mods.shift.hasCtrl, isFalse);

      expect(Mods.ctrl.hasCtrl, isTrue);
      expect(Mods.ctrl.hasShift, isFalse);

      expect(Mods.alt.hasAlt, isTrue);
      expect(Mods.alt.hasCtrl, isFalse);

      expect(Mods.superKey.hasSuper, isTrue);
      expect(Mods.superKey.hasAlt, isFalse);

      expect(Mods.capsLock.hasCapsLock, isTrue);
      expect(Mods.capsLock.hasNumLock, isFalse);

      expect(Mods.numLock.hasNumLock, isTrue);
      expect(Mods.numLock.hasCapsLock, isFalse);
    });

    test('side getters return correct results', () {
      final rightShift = Mods.shift | Mods.shiftSide;
      expect(rightShift.isShiftRight, isTrue);
      expect(rightShift.hasShift, isTrue);

      expect(Mods.shift.isShiftRight, isFalse);

      final rightCtrl = Mods.ctrl | Mods.ctrlSide;
      expect(rightCtrl.isCtrlRight, isTrue);

      final rightAlt = Mods.alt | Mods.altSide;
      expect(rightAlt.isAltRight, isTrue);

      final rightSuper = Mods.superKey | Mods.superSide;
      expect(rightSuper.isSuperRight, isTrue);
    });

    test('isEmpty returns false for non-empty mods', () {
      expect(Mods.shift.isEmpty, isFalse);
      expect((Mods.ctrl | Mods.alt).isEmpty, isFalse);
    });

    test('equality compares by value', () {
      expect(Mods.ctrl | Mods.shift, equals(Mods.shift | Mods.ctrl));
      expect(Mods.ctrl, isNot(equals(Mods.alt)));
      expect(Mods.none, equals(Mods.none));
    });

    test('hashCode is consistent with equality', () {
      final a = Mods.ctrl | Mods.shift;
      final b = Mods.shift | Mods.ctrl;
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString for none', () {
      expect(Mods.none.toString(), 'Mods.none');
    });

    test('toString for single modifier', () {
      expect(Mods.ctrl.toString(), 'Mods(ctrl)');
      expect(Mods.shift.toString(), 'Mods(shift)');
    });

    test('toString for combined modifiers', () {
      final combined = Mods.ctrl | Mods.shift;
      final str = combined.toString();
      expect(str, contains('shift'));
      expect(str, contains('ctrl'));
    });

    test('toString shows side info when present', () {
      final rightShift = Mods.shift | Mods.shiftSide;
      expect(rightShift.toString(), contains('shiftRight'));

      const leftCtrl = Mods.ctrl;
      expect(leftCtrl.toString(), contains('ctrl'));
      expect(leftCtrl.toString(), isNot(contains('ctrlRight')));
    });
  });
}

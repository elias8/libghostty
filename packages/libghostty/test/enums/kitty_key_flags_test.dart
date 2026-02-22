import 'package:libghostty/input.dart';
import 'package:test/test.dart';

void main() {
  group('KittyKeyFlags', () {
    test('disabled has value 0', () {
      expect(KittyKeyFlags.disabled.value, 0);
      expect(KittyKeyFlags.disabled.isDisabled, isTrue);
    });

    test('named constants have correct bit values', () {
      expect(KittyKeyFlags.disambiguate.value, 1 << 0);
      expect(KittyKeyFlags.reportEvents.value, 1 << 1);
      expect(KittyKeyFlags.reportAlternates.value, 1 << 2);
      expect(KittyKeyFlags.reportAll.value, 1 << 3);
      expect(KittyKeyFlags.reportAssociated.value, 1 << 4);
    });

    test('all combines all flags', () {
      expect(KittyKeyFlags.all.value, 0x1F);
      expect(KittyKeyFlags.all.isDisabled, isFalse);
    });

    test('| operator combines flags', () {
      final combined = KittyKeyFlags.disambiguate | KittyKeyFlags.reportEvents;
      expect(combined.value, 3);
      expect(combined.isDisabled, isFalse);
    });

    test('isDisabled returns false for non-zero flags', () {
      expect(KittyKeyFlags.disambiguate.isDisabled, isFalse);
      expect(KittyKeyFlags.all.isDisabled, isFalse);
    });

    test('equality compares by value', () {
      final a = KittyKeyFlags.disambiguate | KittyKeyFlags.reportEvents;
      final b = KittyKeyFlags.reportEvents | KittyKeyFlags.disambiguate;
      expect(a, equals(b));
    });

    test('inequality for different values', () {
      expect(
        KittyKeyFlags.disambiguate,
        isNot(equals(KittyKeyFlags.reportEvents)),
      );
    });

    test('hashCode is consistent with equality', () {
      final a = KittyKeyFlags.disambiguate | KittyKeyFlags.reportAll;
      final b = KittyKeyFlags.reportAll | KittyKeyFlags.disambiguate;
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString contains hex value', () {
      expect(KittyKeyFlags.disambiguate.toString(), 'KittyKeyFlags(0x1)');
      expect(KittyKeyFlags.all.toString(), 'KittyKeyFlags(0x1f)');
    });
  });
}

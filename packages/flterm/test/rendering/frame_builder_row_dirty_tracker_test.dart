import 'package:flterm/src/rendering/frame_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RowDirtyTracker', () {
    group('resize', () {
      test('clears previous marks', () {
        final tracker = RowDirtyTracker()..resize(4);
        tracker.markRow(2);
        expect(tracker.anyDirty, isTrue);

        tracker.resize(6);

        expect(tracker.anyDirty, isFalse);
        expect(tracker.isDirty(0), isFalse);
        expect(tracker.isDirty(2), isFalse);
        expect(tracker.isDirty(5), isFalse);
      });

      test('reuses existing buffer when big enough', () {
        final tracker = RowDirtyTracker()..resize(100);
        tracker.markAll();

        tracker.resize(10);
        expect(tracker.isDirty(0), isFalse);
        expect(tracker.isDirty(5), isFalse);
        expect(tracker.isDirty(9), isFalse);

        tracker.resize(50);
        expect(tracker.anyDirty, isFalse);
      });
    });

    group('markRow', () {
      test('flags a single row', () {
        final tracker = RowDirtyTracker()..resize(4);
        tracker.markRow(2);

        expect(tracker.anyDirty, isTrue);
        expect(tracker.isDirty(2), isTrue);
        expect(tracker.isDirty(0), isFalse);
        expect(tracker.isDirty(3), isFalse);
      });

      test('ignores out-of-range indices', () {
        final tracker = RowDirtyTracker()..resize(4);
        tracker.markRow(-1);
        tracker.markRow(99);

        expect(tracker.anyDirty, isFalse);
      });
    });

    group('markRange', () {
      test('flags an inclusive-exclusive range', () {
        final tracker = RowDirtyTracker()..resize(10);
        tracker.markRange(3, 7);

        expect(tracker.isDirty(2), isFalse);
        expect(tracker.isDirty(3), isTrue);
        expect(tracker.isDirty(6), isTrue);
        expect(tracker.isDirty(7), isFalse);
      });

      test('clips out-of-range ends', () {
        final tracker = RowDirtyTracker()..resize(5);
        tracker.markRange(-5, 3);
        tracker.markRange(4, 100);

        expect(tracker.isDirty(0), isTrue);
        expect(tracker.isDirty(2), isTrue);
        expect(tracker.isDirty(3), isFalse);
        expect(tracker.isDirty(4), isTrue);
      });

      test('leaves anyDirty false when no mark lands', () {
        final tracker = RowDirtyTracker()..resize(3);
        tracker.markRange(5, 10);

        expect(tracker.anyDirty, isFalse);
      });
    });

    group('markAll', () {
      test('flags every row', () {
        final tracker = RowDirtyTracker()..resize(5);
        tracker.markAll();

        expect(tracker.anyDirty, isTrue);
        expect(tracker.isDirty(0), isTrue);
        expect(tracker.isDirty(2), isTrue);
        expect(tracker.isDirty(4), isTrue);
      });
    });
  });
}

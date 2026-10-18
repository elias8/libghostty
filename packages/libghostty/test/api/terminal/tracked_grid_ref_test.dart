import 'dart:typed_data' show Uint8List;

import 'package:libghostty/libghostty.dart'
    show GridRef, InvalidValueException, Position, Terminal, TrackedGridRef;
import 'package:test/test.dart';

import '../../helpers/setup.dart';

void main() {
  setUp(() => testEnvironment);

  group('TrackedGridRef', () {
    late Terminal terminal;

    setUp(() {
      terminal = Terminal(cols: 80, rows: 24);
      terminal.write(Uint8List.fromList('Hello'.codeUnits));
    });

    tearDown(() {
      terminal.dispose();
    });

    group('at', () {
      test('throws for an out of range column', () {
        expect(
          () => TrackedGridRef.at(terminal, const Position(row: 0, col: 80)),
          throwsA(isA<InvalidValueException>()),
        );
      });
    });

    group('hasValue', () {
      test('returns true for a live cell', () {
        final tracked = TrackedGridRef.at(
          terminal,
          const Position(row: 0, col: 0),
        );
        addTearDown(tracked.dispose);

        final result = tracked.hasValue;

        expect(result, isTrue);
      });

      test('returns false after reset', () {
        final tracked = TrackedGridRef.at(
          terminal,
          const Position(row: 0, col: 0),
        );
        addTearDown(tracked.dispose);

        terminal.reset();
        final result = tracked.hasValue;

        expect(result, isFalse);
      });
    });

    group('positionIn', () {
      test('returns coordinates in the requested coordinate space', () {
        final tracked = TrackedGridRef.at(
          terminal,
          const Position(row: 0, col: 1),
        );
        addTearDown(tracked.dispose);

        final result = tracked.positionIn(.active);

        expect(result, const Position(row: 0, col: 1));
      });

      test('returns null after reset', () {
        final tracked = TrackedGridRef.at(
          terminal,
          const Position(row: 0, col: 0),
        );
        addTearDown(tracked.dispose);

        terminal.reset();
        final result = tracked.positionIn(.active);

        expect(result, isNull);
      });
    });

    group('set', () {
      test('moves the tracked position', () {
        final tracked = TrackedGridRef.at(
          terminal,
          const Position(row: 0, col: 0),
        );
        addTearDown(tracked.dispose);

        tracked.set(const Position(row: 0, col: 2));
        final result = tracked.positionIn(.active);

        expect(result, const Position(row: 0, col: 2));
      });

      test('throws for an out of range column', () {
        final tracked = TrackedGridRef.at(
          terminal,
          const Position(row: 0, col: 0),
        );
        addTearDown(tracked.dispose);

        expect(
          () => tracked.set(const Position(row: 0, col: 80)),
          throwsA(isA<InvalidValueException>()),
        );
      });
    });

    group('snapshot', () {
      test('returns a grid reference for a live cell', () {
        final tracked = TrackedGridRef.at(
          terminal,
          const Position(row: 0, col: 1),
        );
        addTearDown(tracked.dispose);

        final result = tracked.snapshot();

        expect(result, isA<GridRef>());
      });

      test('returns content from the tracked cell', () {
        final tracked = TrackedGridRef.at(
          terminal,
          const Position(row: 0, col: 1),
        );
        addTearDown(tracked.dispose);

        final result = tracked.snapshot();

        expect(result!.content, 'e');
      });

      test('returns null after reset', () {
        final tracked = TrackedGridRef.at(
          terminal,
          const Position(row: 0, col: 0),
        );
        addTearDown(tracked.dispose);

        terminal.reset();
        final result = tracked.snapshot();

        expect(result, isNull);
      });

      test('follows the cell after scrolling', () {
        final scrolled = Terminal(cols: 8, rows: 3);
        addTearDown(scrolled.dispose);
        scrolled.write(
          Uint8List.fromList('alpha\r\nbravo\r\ncharlie'.codeUnits),
        );
        final tracked = TrackedGridRef.at(
          scrolled,
          const Position(row: 0, col: 0),
        );
        addTearDown(tracked.dispose);

        scrolled.write(Uint8List.fromList('\r\ndelta'.codeUnits));
        final result = tracked.snapshot();

        expect(result!.content, 'a');
      });
    });

    test('loses its value after terminal disposal', () {
      final tracked = TrackedGridRef.at(
        terminal,
        const Position(row: 0, col: 0),
      );
      addTearDown(tracked.dispose);

      terminal.dispose();

      expect(tracked.hasValue, isFalse);
      expect(tracked.snapshot(), isNull);
      expect(tracked.positionIn(.active), isNull);
      expect(
        () => tracked.set(const Position(row: 0, col: 1)),
        throwsStateError,
      );
      expect(tracked.dispose, returnsNormally);
    });

    group('dispose', () {
      test('is idempotent', () {
        final tracked = TrackedGridRef.at(
          terminal,
          const Position(row: 0, col: 0),
        );
        addTearDown(tracked.dispose);

        tracked.dispose();

        expect(tracked.dispose, returnsNormally);
      });

      test('rejects all operations after disposal', () {
        final tracked = TrackedGridRef.at(
          terminal,
          const Position(row: 0, col: 0),
        );
        addTearDown(tracked.dispose);
        tracked.dispose();

        tracked.dispose();

        expect(() => tracked.hasValue, throwsStateError);
        expect(() => tracked.positionIn(.active), throwsStateError);
        expect(
          () => tracked.set(const Position(row: 0, col: 1)),
          throwsStateError,
        );
        expect(tracked.snapshot, throwsStateError);
      });
    });
  });
}

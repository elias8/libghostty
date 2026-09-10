@Tags(['ffi'])
library;

import 'package:flterm/src/interaction/selection_session.dart'
    show SelectionInteraction, SelectionSession;
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart'
    show PointTag, Position, SelectionOrder, Terminal;

void main() {
  group('SelectionSession', () {
    late Terminal terminal;
    late SelectionInteraction subject;
    late SelectionSession selection;
    late int notifications;

    setUp(() {
      terminal = Terminal(cols: 8, rows: 3);
      notifications = 0;
      selection = SelectionSession(terminal, () => notifications++);
      subject = selection.createInteraction();
      addTearDown(terminal.dispose);
      addTearDown(subject.dispose);
    });

    void select({
      Position start = const Position(row: 1, col: 2),
      Position end = const Position(row: 1, col: 5),
      bool rectangle = false,
    }) {
      selection.selectRange(
        start: start,
        end: end,
        pointTag: PointTag.viewport,
        rectangle: rectangle,
      );
    }

    group('endpoint update', () {
      test('notifies listeners when selection changes', () {
        var changes = 0;
        subject.addListener(() => changes++);

        select();

        expect(changes, 1);
      });

      test('notifies listeners when selection clears', () {
        select();
        var changes = 0;
        subject.addListener(() => changes++);

        selection.clear(notify: true);

        expect(changes, 1);
      });

      test('ignores updates without an active selection', () {
        subject.updateEndpoint(.start, const Position(row: 0, col: 0));

        expect(notifications, 0);
      });

      test('replaces only the start endpoint', () {
        select();

        subject.updateEndpoint(.start, const Position(row: 0, col: 1));

        final selection = terminal.selection!;
        expect(
          (
            start: selection.start.positionIn(.viewport),
            end: selection.end.positionIn(.viewport),
          ),
          (
            start: const Position(row: 0, col: 1),
            end: const Position(row: 1, col: 5),
          ),
        );
      });

      test('replaces only the end endpoint', () {
        select();

        subject.updateEndpoint(.end, const Position(row: 2, col: 7));

        final selection = terminal.selection!;
        expect(
          (
            start: selection.start.positionIn(.viewport),
            end: selection.end.positionIn(.viewport),
          ),
          (
            start: const Position(row: 1, col: 2),
            end: const Position(row: 2, col: 7),
          ),
        );
      });

      test('preserves endpoint ownership after crossing', () {
        select(
          start: const Position(row: 0, col: 1),
          end: const Position(row: 0, col: 5),
        );

        subject.updateEndpoint(.start, const Position(row: 0, col: 6));

        final selection = terminal.selection!;
        expect(
          (
            order: selection.order,
            start: selection.start.positionIn(.viewport),
          ),
          (
            order: SelectionOrder.reverse,
            start: const Position(row: 0, col: 6),
          ),
        );
      });

      test('preserves rectangular selection shape', () {
        select(
          start: const Position(row: 0, col: 1),
          end: const Position(row: 2, col: 5),
          rectangle: true,
        );

        subject.updateEndpoint(.end, const Position(row: 1, col: 3));

        expect(terminal.selection!.rectangle, isTrue);
      });

      test('replaces rectangular selection shape when requested', () {
        select(
          start: const Position(row: 0, col: 1),
          end: const Position(row: 2, col: 5),
          rectangle: true,
        );

        subject.updateEndpoint(
          .end,
          const Position(row: 1, col: 3),
          rectangle: false,
        );

        expect(terminal.selection!.rectangle, isFalse);
      });

      test('clamps the moving endpoint to the viewport', () {
        select(start: const Position(row: 1, col: 1));

        subject.updateEndpoint(.end, const Position(row: 20, col: 20));

        expect(
          terminal.selection!.end.positionIn(.viewport),
          const Position(row: 2, col: 7),
        );
      });

      test('suppresses equivalent endpoint notifications', () {
        select(start: const Position(row: 1, col: 1));
        notifications = 0;

        subject.updateEndpoint(.end, const Position(row: 1, col: 5));

        expect(notifications, 0);
      });
    });

    group('interaction lifecycle', () {
      test('rejects a second active interaction', () {
        expect(() => selection.createInteraction(), throwsA(isA<StateError>()));
      });

      test('notifies a recreated interaction when selection changes', () {
        subject.dispose();

        final replacement = selection.createInteraction();
        addTearDown(replacement.dispose);
        var changes = 0;
        replacement.addListener(() => changes++);

        selection.selectRange(
          start: const Position(row: 0, col: 0),
          end: const Position(row: 0, col: 1),
          pointTag: PointTag.viewport,
          rectangle: false,
        );

        expect(changes, 1);
      });

      test('ignores disposal of an old interaction after recreation', () {
        subject.dispose();
        final replacement = selection.createInteraction();
        addTearDown(replacement.dispose);
        var changes = 0;
        replacement.addListener(() => changes++);

        subject.dispose();
        selection.selectRange(
          start: const Position(row: 0, col: 0),
          end: const Position(row: 0, col: 1),
          pointTag: PointTag.viewport,
          rectangle: false,
        );

        expect(changes, 1);
      });
    });
  });
}

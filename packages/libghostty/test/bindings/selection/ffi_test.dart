@Tags(['ffi'])
library;

import 'dart:typed_data';

import 'package:libghostty/src/bindings/selection/ffi.dart';
import 'package:libghostty/src/bindings/terminal/ffi.dart';
import 'package:libghostty/src/bindings/types.dart' show RawSelection;
import 'package:test/test.dart';

void main() {
  group('FfiSelectionBindings', () {
    late FfiSelectionBindings selection;
    late FfiTerminalBindings terminalBindings;

    setUp(() {
      selection = FfiSelectionBindings();
      terminalBindings = FfiTerminalBindings();
    });

    test('creates and clears a selection gesture event', () {
      final event = selection.selectionGestureEventNew(.press);
      addTearDown(() => selection.selectionGestureEventFree(event));

      selection.selectionGestureEventClear(event, .position);

      expect(event.value, isNonZero);
    });

    test('formats a selected terminal range through the direct adapter', () {
      final terminal = terminalBindings.terminalNew(8, 2);
      addTearDown(() => terminalBindings.terminalFree(terminal));
      terminalBindings.terminalVtWrite(
        terminal,
        Uint8List.fromList([65, 66, 67]),
      );

      final selected = selection.terminalSelectAll(terminal);
      final formatted = selection.terminalSelectionFormat(
        terminal,
        .plain,
        selection: selected,
      );

      expect(selected, isNotNull);
      expect(formatted, contains('ABC'));
    });

    test('formats successive explicit selections without stale endpoints', () {
      final terminal = terminalBindings.terminalNew(8, 2);
      addTearDown(() => terminalBindings.terminalFree(terminal));
      terminalBindings.terminalVtWrite(
        terminal,
        Uint8List.fromList('ABC'.codeUnits),
      );
      final whole = selection.terminalSelectAll(terminal)!;
      final first = _range(whole, 0, 1);
      final second = _range(whole, 1, 2);

      expect(
        selection.terminalSelectionFormat(terminal, .plain, selection: first),
        'AB',
      );
      expect(
        selection.terminalSelectionFormat(terminal, .plain, selection: second),
        'BC',
      );
    });

    test(
      'clears an explicit selection pointer before using the active one',
      () {
        final terminal = terminalBindings.terminalNew(8, 2);
        addTearDown(() => terminalBindings.terminalFree(terminal));
        terminalBindings.terminalVtWrite(
          terminal,
          Uint8List.fromList('ABC'.codeUnits),
        );
        final active = selection.terminalSelectAll(terminal)!;
        selection.terminalSetSelection(terminal, active);

        expect(
          selection.terminalSelectionFormat(
            terminal,
            .plain,
            selection: _range(active, 0, 1),
          ),
          'AB',
        );
        expect(selection.terminalSelectionFormat(terminal, .plain), 'ABC');

        selection.terminalSetSelection(terminal, null);
        expect(selection.terminalSelectionFormat(terminal, .plain), isNull);
      },
    );

    test('formats explicit selections across terminals', () {
      final firstTerminal = terminalBindings.terminalNew(8, 2);
      final secondTerminal = terminalBindings.terminalNew(8, 2);
      addTearDown(() => terminalBindings.terminalFree(firstTerminal));
      addTearDown(() => terminalBindings.terminalFree(secondTerminal));
      terminalBindings.terminalVtWrite(
        firstTerminal,
        Uint8List.fromList('ABC'.codeUnits),
      );
      terminalBindings.terminalVtWrite(
        secondTerminal,
        Uint8List.fromList('XYZ'.codeUnits),
      );
      final first = _range(selection.terminalSelectAll(firstTerminal)!, 0, 1);
      final second = _range(selection.terminalSelectAll(secondTerminal)!, 1, 2);

      expect(
        selection.terminalSelectionFormat(
          firstTerminal,
          .plain,
          selection: first,
        ),
        'AB',
      );
      expect(
        selection.terminalSelectionFormat(
          secondTerminal,
          .plain,
          selection: second,
        ),
        'YZ',
      );
    });
  });
}

RawSelection _range(RawSelection source, int start, int end) => (
  start: (node: source.start.node, x: start, y: 0),
  end: (node: source.end.node, x: end, y: 0),
  rectangle: false,
);

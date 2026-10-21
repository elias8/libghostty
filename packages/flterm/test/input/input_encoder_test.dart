@Tags(['ffi'])
library;

import 'dart:convert';

import 'package:flterm/src/foundation/surface_geometry.dart';
import 'package:flterm/src/input/input_encoder.dart';
import 'package:flterm/src/input/input_message.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart';

void main() {
  group('InputEncoder', () {
    late Terminal terminal;
    late InputEncoder encoder;

    setUp(() {
      terminal = Terminal(cols: 80, rows: 24);
      encoder = InputEncoder(terminal);
    });

    tearDown(() {
      encoder.dispose();
      terminal.dispose();
    });

    test('disposal before input is idempotent and rejects new work', () {
      encoder.updateGeometry(_geometry());
      encoder.dispose();
      encoder.dispose();

      expect(
        () => encoder.encodeKeyPress(Key.arrowUp, mods: const .none()),
        throwsStateError,
      );
      expect(
        () => encoder.encodeMouse(_press, geometry: null),
        throwsStateError,
      );
      expect(() => encoder.updateGeometry(_geometry()), throwsStateError);
    });

    test('reused keyboard resources follow live terminal modes', () {
      expect(
        encoder.encodeKeyPress(Key.arrowUp, mods: const .none()),
        '\x1b[A',
      );
      terminal.write(utf8.encode('\x1b[?1h'));
      expect(
        encoder.encodeKeyPress(Key.arrowUp, mods: const .none()),
        '\x1bOA',
      );
      expect(
        encoder.encodeKey(
          const KeyInput(
            action: .press,
            character: ' ',
            composing: false,
            consumedMods: .none(),
            key: .space,
            mods: .ctrl(),
            unshiftedCodepoint: 32,
          ),
        ),
        '\x00',
      );
      expect(
        encoder.encodeKeyPress(Key.arrowUp, mods: const .none()),
        '\x1bOA',
      );
    });

    test('first pointer input uses the latest encoder size', () {
      terminal.write(utf8.encode('\x1b[?1000h\x1b[?1006h'));
      final positionGeometry = _geometry();
      encoder.updateGeometry(positionGeometry);
      encoder.updateGeometry(_geometry(cellWidth: 16, cellHeight: 32));

      expect(
        encoder.encodeMouse(_press, geometry: positionGeometry),
        '\x1b[<0;2;2M',
      );
      encoder.updateGeometry(positionGeometry);
      expect(
        encoder.encodeMouse(_press, geometry: positionGeometry),
        '\x1b[<0;3;3M',
      );
    });

    test('first wheel input uses current size and clamps to the grid', () {
      terminal.write(utf8.encode('\x1b[?1000h\x1b[?1006h'));
      encoder.updateGeometry(_geometry());
      final geometry = _geometry(cellWidth: 16, cellHeight: 32);
      encoder.updateGeometry(geometry);

      expect(
        encoder.encodeScrollButton(
          const ScrollInput(
            mods: .none(),
            pixelX: 2000,
            pixelY: 1000,
            vertical: 1,
            horizontal: 0,
            reportMouse: true,
          ),
          button: .five,
          geometry: geometry,
        ),
        '\x1b[<65;80;24M',
      );
    });

    test(
      'mouse reuse clears a previous button and follows tracking changes',
      () {
        terminal.write(utf8.encode('\x1b[?1000h\x1b[?1006h'));
        final geometry = _geometry();
        encoder.updateGeometry(geometry);
        expect(encoder.encodeMouse(_press, geometry: geometry), '\x1b[<0;3;3M');
        terminal.write(utf8.encode('\x1b[?1003h'));

        expect(
          encoder.encodeMouse(
            const MouseInput(
              action: .motion,
              anyButtonPressed: false,
              button: null,
              mods: .none(),
              pixelX: 17,
              pixelY: 33,
            ),
            geometry: geometry,
          ),
          '\x1b[<35;3;3M',
        );
      },
    );
  });
}

const _press = MouseInput(
  action: .press,
  anyButtonPressed: true,
  button: .left,
  mods: .none(),
  pixelX: 17,
  pixelY: 33,
);

SurfaceGeometry _geometry({double cellWidth = 8, double cellHeight = 16}) {
  return SurfaceGeometry.tryFrom(
    SurfaceMeasurement(
      cols: 80,
      rows: 24,
      cellWidth: cellWidth,
      cellHeight: cellHeight,
      paddingLeft: 0,
      paddingRight: 0,
      paddingTop: 0,
      paddingBottom: 0,
      devicePixelRatio: 1,
    ),
  )!;
}

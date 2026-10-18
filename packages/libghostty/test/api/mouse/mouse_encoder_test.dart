import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

import '../../helpers/setup.dart';

void main() {
  setUp(() => testEnvironment);

  group('MouseEncoder', () {
    late MouseEncoder encoder;
    late MouseEvent event;

    setUp(() {
      encoder = MouseEncoder();
      event = MouseEvent()
        ..action = MouseAction.press
        ..button = MouseButton.left
        ..setPosition(x: 10.0, y: 5.0);
    });

    tearDown(() {
      event.dispose();
      encoder.dispose();
    });

    group('encode', () {
      test('returns empty without tracking mode', () {
        expect(encoder.encode(event), isEmpty);
      });

      test('returns SGR sequence after terminal sync enables tracking', () {
        final terminal = Terminal(cols: 80, rows: 24);
        addTearDown(terminal.dispose);

        terminal.write(.fromList('\x1b[?1000h\x1b[?1006h'.codeUnits));

        encoder.sync(terminal);
        encoder.setSize(
          const MouseEncoderSize(
            screenWidth: 640,
            screenHeight: 384,
            cellWidth: 8,
            cellHeight: 16,
          ),
        );

        event
          ..action = MouseAction.press
          ..button = MouseButton.left
          ..setPosition(x: 24.0, y: 32.0);

        final result = encoder.encode(event);
        expect(result, '\x1b[<0;4;3M');
      });

      test('returns SGR sequence with manual tracking and format', () {
        encoder.setTrackingMode(MouseTracking.normal);
        encoder.setFormat(MouseFormat.sgr);
        encoder.setSize(
          const MouseEncoderSize(
            screenWidth: 640,
            screenHeight: 384,
            cellWidth: 8,
            cellHeight: 16,
          ),
        );

        event
          ..action = MouseAction.press
          ..button = MouseButton.left
          ..setPosition(x: 24.0, y: 32.0);

        final result = encoder.encode(event);
        expect(result, '\x1b[<0;4;3M');
      });
    });

    group('setSize', () {
      test('accepts padding values', () {
        encoder.setSize(
          const MouseEncoderSize(
            screenWidth: 800,
            screenHeight: 600,
            cellWidth: 8,
            cellHeight: 16,
            paddingTop: 4,
            paddingBottom: 4,
            paddingLeft: 4,
            paddingRight: 4,
          ),
        );

        expect(encoder.encode(event), isEmpty);
      });
    });

    group('reset', () {
      test('clears motion deduplication and preserves configured options', () {
        encoder
          ..setTrackingMode(MouseTracking.any)
          ..setFormat(MouseFormat.sgr)
          ..setSize(
            const MouseEncoderSize(
              screenWidth: 640,
              screenHeight: 384,
              cellWidth: 8,
              cellHeight: 16,
            ),
          )
          ..setTrackLastCell(enabled: true);
        event
          ..action = MouseAction.motion
          ..clearButton()
          ..setPosition(x: 24.0, y: 32.0);

        expect(encoder.encode(event), '\x1b[<35;4;3M');
        expect(encoder.encode(event), isEmpty);

        encoder.reset();

        expect(encoder.encode(event), '\x1b[<35;4;3M');
        expect(encoder.encode(event), isEmpty);
      });
    });

    group('dispose', () {
      test('can be called more than once', () {
        encoder.dispose();

        expect(encoder.dispose, returnsNormally);
      });

      test('rejects all operations after disposal', () {
        final terminal = Terminal(cols: 80, rows: 24);
        addTearDown(terminal.dispose);
        encoder.dispose();

        expect(encoder.reset, throwsStateError);
        expect(() => encoder.encode(event), throwsStateError);
        expect(
          () => encoder.setAnyButtonPressed(pressed: true),
          throwsStateError,
        );
        expect(() => encoder.setFormat(MouseFormat.sgr), throwsStateError);
        expect(
          () => encoder.setSize(
            const MouseEncoderSize(
              screenWidth: 640,
              screenHeight: 384,
              cellWidth: 8,
              cellHeight: 16,
            ),
          ),
          throwsStateError,
        );
        expect(
          () => encoder.setTrackingMode(MouseTracking.normal),
          throwsStateError,
        );
        expect(() => encoder.setTrackLastCell(enabled: true), throwsStateError);
        expect(() => encoder.sync(terminal), throwsStateError);
      });
    });
  });
}

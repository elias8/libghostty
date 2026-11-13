import 'dart:convert';
import 'dart:typed_data';

import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

import '../helpers/setup.dart';

void main() {
  setUp(() => testEnvironment);

  test('formats empty, single ASCII and multibyte output after updates', () {
    final terminal = Terminal(cols: 8, rows: 1);
    addTearDown(terminal.dispose);
    final formatter = Formatter(
      terminal: terminal,
      format: FormatterFormat.plain,
      trim: true,
    );
    addTearDown(formatter.dispose);
    for (final text in ['', 'A', '~', 'é', '€', '😀', 'Z', '']) {
      terminal.write(
        Uint8List.fromList([27, 91, 50, 74, 27, 91, 72, ...utf8.encode(text)]),
      );
      expect(formatter.format(), text);
    }
  });

  group('Formatter', () {
    late Terminal terminal;

    setUp(() {
      terminal = Terminal(cols: 80, rows: 24);
    });

    tearDown(() {
      terminal.dispose();
    });

    group('format', () {
      test('returns terminal content for plain format', () {
        terminal.write(Uint8List.fromList('Hello World'.codeUnits));
        final formatter = Formatter(
          terminal: terminal,
          format: FormatterFormat.plain,
        );
        addTearDown(formatter.dispose);

        final result = formatter.format();
        expect(result, contains('Hello World'));
      });

      test('preserves escape sequences for vt format', () {
        terminal.write(Uint8List.fromList('\x1b[1mBold\x1b[0m'.codeUnits));
        final formatter = Formatter(
          terminal: terminal,
          format: FormatterFormat.vt,
        );
        addTearDown(formatter.dispose);

        final result = formatter.format();
        expect(result, contains('Bold'));
        expect(result, contains('\x1b['));
      });

      test('strips trailing whitespace when trim is true', () {
        terminal.write(Uint8List.fromList('Hi'.codeUnits));
        final trimmed = Formatter(
          terminal: terminal,
          format: FormatterFormat.plain,
          trim: true,
        );
        addTearDown(trimmed.dispose);

        final result = trimmed.format();
        expect(result.trimRight(), result);
      });

      test('includes CUP sequence for cursor extra', () {
        terminal.write(Uint8List.fromList('Hi'.codeUnits));
        final formatter = Formatter(
          terminal: terminal,
          format: FormatterFormat.vt,
          extra: const FormatterExtra(cursor: true),
        );
        addTearDown(formatter.dispose);

        final result = formatter.format();
        expect(result, contains('\x1b['));
        expect(result, contains('H'));
      });

      test('includes additional state for all extras', () {
        terminal.write(Uint8List.fromList('Hi'.codeUnits));
        final withoutExtras = Formatter(
          terminal: terminal,
          format: FormatterFormat.vt,
        );
        final withExtras = Formatter(
          terminal: terminal,
          format: FormatterFormat.vt,
          extra: const FormatterExtra.all(),
        );
        addTearDown(withoutExtras.dispose);
        addTearDown(withExtras.dispose);

        final basic = withoutExtras.format();
        final full = withExtras.format();
        expect(full.length, greaterThan(basic.length));
      });
    });

    test('tracks selected cells across writes, scrolling and resize', () {
      final terminal = Terminal(cols: 8, rows: 3);
      addTearDown(terminal.dispose);
      terminal.write(Uint8List.fromList('alpha\r\nbravo\r\ncharlie'.codeUnits));
      final selection = Selection.fromRefs(
        start: GridRef.at(terminal, const Position(row: 0, col: 0)),
        end: GridRef.at(terminal, const Position(row: 0, col: 4)),
      );
      final formatter = Formatter(
        terminal: terminal,
        format: .plain,
        trim: true,
        selection: selection,
      );
      addTearDown(formatter.dispose);
      expect(formatter.format(), 'alpha');

      terminal.write(Uint8List.fromList('\r\ndelta'.codeUnits));
      expect(formatter.format(), 'alpha');
      terminal.resize(cols: 10, rows: 3, cellWidthPx: 8, cellHeightPx: 16);
      expect(formatter.format(), 'alpha');
    });

    test('reads changed content at tracked selection endpoints', () {
      terminal.write(Uint8List.fromList('Hello'.codeUnits));
      final selection = Selection.fromRefs(
        start: GridRef.at(terminal, const Position(row: 0, col: 0)),
        end: GridRef.at(terminal, const Position(row: 0, col: 4)),
      );
      final formatter = Formatter(
        terminal: terminal,
        format: .plain,
        trim: true,
        selection: selection,
      );
      addTearDown(formatter.dispose);
      expect(formatter.format(), 'Hello');
      terminal.write(Uint8List.fromList('\x1b[HWorld'.codeUnits));
      expect(formatter.format(), 'World');
      expect(formatter.format(), 'World');
    });

    test('rejects selection after reset discards tracked endpoints', () {
      terminal.write(Uint8List.fromList('Hello'.codeUnits));
      final selection = Selection.fromRefs(
        start: GridRef.at(terminal, const Position(row: 0, col: 0)),
        end: GridRef.at(terminal, const Position(row: 0, col: 4)),
      );
      final formatter = Formatter(
        terminal: terminal,
        format: .plain,
        selection: selection,
      );
      addTearDown(formatter.dispose);
      expect(formatter.format(), contains('Hello'));
      terminal.reset();
      expect(formatter.format, throwsStateError);
    });

    test('rejects selection while another screen is active', () {
      terminal.write(Uint8List.fromList('Hello'.codeUnits));
      final selection = Selection.fromRefs(
        start: GridRef.at(terminal, const Position(row: 0, col: 0)),
        end: GridRef.at(terminal, const Position(row: 0, col: 4)),
      );
      final formatter = Formatter(
        terminal: terminal,
        format: .plain,
        trim: true,
        selection: selection,
      );
      addTearDown(formatter.dispose);
      terminal.write(Uint8List.fromList('\x1b[?1049h'.codeUnits));
      expect(formatter.format, throwsStateError);
      terminal.write(Uint8List.fromList('\x1b[?1049l'.codeUnits));
      expect(formatter.format(), 'Hello');
    });

    test('disposes tracked selection after terminal disposal', () {
      final selection = Selection.fromRefs(
        start: GridRef.at(terminal, const Position(row: 0, col: 0)),
        end: GridRef.at(terminal, const Position(row: 0, col: 1)),
      );
      final formatter = Formatter(
        terminal: terminal,
        format: .plain,
        selection: selection,
      );
      terminal.dispose();
      expect(formatter.format, throwsStateError);
      expect(formatter.dispose, returnsNormally);
      expect(formatter.dispose, returnsNormally);
    });

    test('rejects a selection from another terminal', () {
      final other = Terminal(cols: 8, rows: 2);
      addTearDown(other.dispose);
      final selection = Selection.fromRefs(
        start: GridRef.at(other, const Position(row: 0, col: 0)),
        end: GridRef.at(other, const Position(row: 0, col: 1)),
      );
      expect(
        () =>
            Formatter(terminal: terminal, format: .plain, selection: selection),
        throwsArgumentError,
      );
    });

    test('rejects formatting after its terminal is disposed', () {
      terminal.write(Uint8List.fromList('owned content'.codeUnits));
      final formatter = Formatter(
        terminal: terminal,
        format: FormatterFormat.plain,
        trim: true,
      );
      addTearDown(formatter.dispose);
      expect(formatter.format(), contains('owned content'));

      terminal.dispose();

      expect(formatter.format, throwsStateError);
    });

    group('dispose', () {
      test('is idempotent', () {
        final formatter = Formatter(
          terminal: terminal,
          format: FormatterFormat.plain,
        );
        addTearDown(formatter.dispose);

        formatter.dispose();

        expect(formatter.dispose, returnsNormally);
      });

      test('throws StateError when formatting after disposal', () {
        final formatter = Formatter(
          terminal: terminal,
          format: FormatterFormat.plain,
        );
        addTearDown(formatter.dispose);
        formatter.dispose();

        expect(formatter.format, throwsStateError);
      });
    });
  });
}

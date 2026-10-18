import 'dart:typed_data';

import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

import '../../../helpers/setup.dart';

void main() {
  late Terminal terminal;

  setUp(() => testEnvironment);

  setUp(() {
    terminal = Terminal(cols: 80, rows: 24);
  });

  tearDown(() => terminal.dispose());

  test('reply registered during a write survives self clear', () {
    final output = <int>[];
    terminal.onWritePty = output.addAll;
    terminal.onBell = () {
      terminal.onEnquiry = () {
        terminal.onEnquiry = null;
        return Uint8List.fromList([0x61]);
      };
    };

    terminal.write(Uint8List.fromList([7, 5]));

    expect(output, [0x61]);

    terminal.write(Uint8List.fromList([5]));

    expect(output, [0x61]);
  });

  test('empty enquiry emits no PTY bytes', () {
    final output = <int>[];
    terminal.onWritePty = output.addAll;
    terminal.onEnquiry = () => Uint8List(0);

    terminal.write(Uint8List.fromList([5]));

    expect(output, isEmpty);
    terminal.onEnquiry = () => Uint8List.fromList([0x61]);

    terminal.write(Uint8List.fromList([5]));

    expect(output, [0x61]);
  });

  test('empty version reply uses the default version', () {
    final output = <int>[];
    terminal.onWritePty = output.addAll;

    final query = Uint8List.fromList('\x1b[>q'.codeUnits);

    terminal.write(query);
    final defaultReply = List<int>.of(output);
    expect(defaultReply, isNotEmpty);

    output.clear();
    terminal.onXtversion = () => '';

    terminal.write(query);

    expect(output, defaultReply);
  });

  for (final version in [false, true]) {
    for (final replace in [false, true]) {
      test('reply survives self clear version=$version replace=$replace', () {
        final output = <int>[];
        terminal.onWritePty = output.addAll;

        String reply() {
          if (version) {
            terminal.onXtversion = null;
            if (replace) terminal.onXtversion = () => 'second';
          } else {
            terminal.onEnquiry = null;
            if (replace) {
              terminal.onEnquiry = () => Uint8List.fromList('second'.codeUnits);
            }
          }
          return 'first';
        }

        if (version) {
          terminal.onXtversion = reply;
        } else {
          terminal.onEnquiry = () => Uint8List.fromList(reply().codeUnits);
        }

        final query = Uint8List.fromList(version ? '\x1b[>q'.codeUnits : [5]);

        terminal.write(query);

        expect(output, (version ? '\x1bP>|first\x1b\\' : 'first').codeUnits);
        if (replace) {
          output.clear();
          terminal.write(query);
          expect(
            output,
            (version ? '\x1bP>|second\x1b\\' : 'second').codeUnits,
          );
        }
      });
    }

    test('reply self clear preserves thrown error version=$version', () {
      final output = <int>[];
      terminal.onWritePty = output.addAll;

      final query = Uint8List.fromList(version ? '\x1b[>q'.codeUnits : [5]);

      terminal.write(query);
      final defaultReply = List<int>.of(output);

      output.clear();
      final error = StateError('reply failed');

      Never reply() {
        if (version) {
          terminal.onXtversion = null;
        } else {
          terminal.onEnquiry = null;
        }
        throw error;
      }

      if (version) {
        terminal.onXtversion = reply;
      } else {
        terminal.onEnquiry = reply;
      }
      expect(() => terminal.write(query), throwsA(same(error)));

      expect(output, defaultReply);

      output.clear();

      terminal.write(query);

      expect(output, defaultReply);
    });
  }
}

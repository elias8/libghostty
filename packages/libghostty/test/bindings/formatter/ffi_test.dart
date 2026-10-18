@Tags(['ffi'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:libghostty/src/bindings/formatter/ffi.dart';
import 'package:libghostty/src/bindings/terminal/ffi.dart';
import 'package:test/test.dart';

void main() {
  group('FfiFormatterBindings', () {
    test('formats correctly across successive buffer growths', () {
      final terminals = FfiTerminalBindings();
      final formatters = FfiFormatterBindings();
      for (final (cols, rows) in [(128, 40), (256, 80)]) {
        final terminal = terminals.terminalNew(cols, rows);
        addTearDown(() => terminals.terminalFree(terminal));
        final line = 'x' * (cols - 1);
        terminals.terminalVtWrite(
          terminal,
          Uint8List.fromList(utf8.encode(List.filled(rows, line).join('\r\n'))),
        );
        final formatter = formatters.formatterTerminalNew(
          terminal,
          .plain,
          trim: true,
        );
        addTearDown(() => formatters.formatterFree(formatter));
        expect(
          formatters.formatterFormat(formatter),
          List.filled(rows, line).join('\n'),
        );
      }
    });

    test(
      'creates and formats a terminal through direct formatter bindings',
      () {
        final terminalBindings = FfiTerminalBindings();
        final formatterBindings = FfiFormatterBindings();
        final terminal = terminalBindings.terminalNew(8, 2);
        addTearDown(() => terminalBindings.terminalFree(terminal));

        final formatter = formatterBindings.formatterTerminalNew(
          terminal,
          .plain,
        );
        addTearDown(() => formatterBindings.formatterFree(formatter));

        expect(formatterBindings.formatterFormat(formatter), isA<String>());
      },
    );
  });
}

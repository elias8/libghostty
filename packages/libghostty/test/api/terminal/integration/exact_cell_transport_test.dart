import 'dart:convert';
import 'dart:typed_data';

import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

import '../../../helpers/setup.dart';

void main() {
  setUp(() => testEnvironment);

  test(
    'preserves supplementary codepoints through reusable public iterators',
    () {
      final terminal = Terminal(cols: 12, rows: 1);
      final state = RenderState();
      final rows = RowIterator();
      final cells = CellIterator();
      addTearDown(() {
        cells.dispose();
        rows.dispose();
        state.dispose();
        terminal.dispose();
      });

      terminal.write(Uint8List.fromList(utf8.encode('🙂e\u0301')));
      state.update(terminal);

      rows.reset(state);

      expect(rows.next(), isTrue);

      cells.reset(rows);

      expect(cells.next(), isTrue);
      expect(cells.codepoint, 128578);
      expect(cells.content, '🙂');
      expect(cells.wide, CellWidth.wide);

      cells.select(2);
      expect(cells.content, 'e\u0301');
      expect(cells.hasHyperlink, isFalse);
      expect(cells.isProtected, isFalse);
      expect(cells.semanticContent, SemanticContent.output);

      cells.select(4);
      expect(cells.content, '');

      cells.reset(rows);

      expect(() => cells.codepoint, throwsA(isA<InvalidValueException>()));

      expect(cells.next(), isTrue);
      expect(cells.codepoint, 128578);
      state.update(terminal);

      expect(() => cells.codepoint, throwsStateError);
    },
  );
}

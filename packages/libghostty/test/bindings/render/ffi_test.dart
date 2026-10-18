@Tags(['ffi'])
library;

import 'dart:convert' show utf8;
import 'dart:typed_data' show Uint8List;

import 'package:libghostty/src/bindings/render/ffi.dart';
import 'package:libghostty/src/bindings/selection/ffi.dart';
import 'package:libghostty/src/bindings/terminal/ffi.dart';
import 'package:libghostty/src/bindings/types.dart'
    show RawCellData, RawCellsView;
import 'package:libghostty/src/types/exceptions.dart';
import 'package:libghostty/src/types/types.dart' show Position;
import 'package:test/test.dart';

void main() {
  group('FfiRenderBindings', () {
    late FfiRenderBindings render;
    late FfiTerminalBindings terminalBindings;

    setUp(() {
      render = FfiRenderBindings();
      terminalBindings = FfiTerminalBindings();
    });

    group('renderStateGetSummary', () {
      test('returns the current dimensions through the direct adapter', () {
        final terminal = terminalBindings.terminalNew(8, 4);
        final state = render.renderStateNew();
        addTearDown(() {
          render.renderStateFree(state);
          terminalBindings.terminalFree(terminal);
        });

        render.renderStateUpdate(state, terminal);

        final summary = render.renderStateGetSummary(state);

        expect(summary.cols, 8);
        expect(summary.rows, 4);
      });

      test('maps an invalid render handle to the public exception type', () {
        expect(
          () => render.renderStateGetSummary(const .fromAddress(0)),
          throwsA(isA<LibGhosttyException>()),
        );
      });
    });

    test('decodes borrowed row cells to the native getter values', () {
      final terminal = terminalBindings.terminalNew(12, 1);
      final selectionBindings = FfiSelectionBindings();
      final state = render.renderStateNew();
      final rows = render.rowIteratorNew();
      final cells = render.rowCellsNew();
      addTearDown(() {
        render.rowCellsFree(cells);
        render.rowIteratorFree(rows);
        render.renderStateFree(state);
        terminalBindings.terminalFree(terminal);
      });

      terminalBindings.terminalVtWrite(
        terminal,
        Uint8List.fromList(
          utf8.encode(
            '\u001b[48;2;4;5;6m\u001b[2K\u001b[1;1H'
            '\u001b]133;A\u0007'
            '\u001b[1;38;2;1;2;3m\u001b[1"q'
            '\u001b]8;;https://example.com\u001b\\A'
            '\u001b]8;;\u001b\\\u001b[0"q界e\u0301',
          ),
        ),
      );
      final selectionStart = render.terminalGridRef(
        terminal,
        .active,
        const Position(row: 0, col: 0),
      );
      final selectionEnd = render.terminalGridRef(
        terminal,
        .active,
        const Position(row: 0, col: 11),
      );
      selectionBindings.terminalSetSelection(terminal, (
        start: selectionStart,
        end: selectionEnd,
        rectangle: false,
      ));
      render.renderStateUpdate(state, terminal);
      render.rowIteratorInit(rows, state);
      expect(render.rowIteratorNext(rows), isTrue);
      render.rowCellsInit(cells, rows);

      final view = RawCellsView();
      expect(render.rowIteratorGetRawCells(rows, view), isTrue);
      expect(view.length, 12);
      final decoded = RawCellData();
      final decodedCodepoints = <int>[];
      final graphemeColumns = <int>[];
      final backgroundColumns = <int>[];
      var sawProtected = false;
      var sawHyperlink = false;
      var sawSemanticPrompt = false;

      for (var col = 0; col < view.length; col++) {
        expect(render.decodeRawCell(view, col, decoded), isTrue);
        render.rowCellsSelect(cells, col);
        final cell = render.rowCellsGetRawCell(cells);
        decodedCodepoints.add(decoded.codepoint);
        if (decoded.hasGrapheme) graphemeColumns.add(col);
        if (decoded.hasBackgroundRgb) backgroundColumns.add(col);
        sawProtected |= decoded.isProtected;
        sawHyperlink |= decoded.hasHyperlink;
        sawSemanticPrompt |= decoded.semanticContent != .output;
        expect(decoded.contentTag, render.cellGetContentTag(cell));
        expect(decoded.codepoint, render.cellGetCodepoint(cell));
        expect(decoded.styleId, render.cellGetStyleId(cell));
        expect(decoded.wide, render.cellGetWide(cell));
        expect(decoded.isProtected, render.cellGetProtected(cell));
        expect(decoded.hasHyperlink, render.cellGetHasHyperlink(cell));
        expect(decoded.semanticContent, render.cellGetSemanticContent(cell));
        if (decoded.hasBackgroundRgb) {
          final color = render.cellGetColorRgb(cell);
          expect(decoded.backgroundR, color.r);
          expect(decoded.backgroundG, color.g);
          expect(decoded.backgroundB, color.b);
        }
        expect(view.isSelected(col), isTrue);
        expect(view.isSelected(col), render.rowCellsGetSelected(cells));
      }

      expect(decodedCodepoints.take(5), [0x41, 0x754c, 0, 0x65, 0]);
      expect(graphemeColumns, [3]);
      expect(decodedCodepoints.skip(5), everyElement(0));
      expect(backgroundColumns, [4, 5, 6, 7, 8, 9, 10, 11]);
      expect(sawProtected, isTrue);
      expect(sawHyperlink, isTrue);
      expect(sawSemanticPrompt, isTrue);
      expect(render.decodeRawCell(view, -1, decoded), isFalse);
      expect(render.decodeRawCell(view, view.length, decoded), isFalse);
    });
  });
}

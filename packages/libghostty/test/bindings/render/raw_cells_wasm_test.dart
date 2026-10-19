@Tags(['wasm'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:libghostty/src/bindings/render/wasm.dart';
import 'package:libghostty/src/bindings/selection/wasm.dart';
import 'package:libghostty/src/bindings/terminal/wasm.dart';
import 'package:libghostty/src/bindings/types.dart';
import 'package:libghostty/src/generated/libghostty_enums.g.dart';
import 'package:libghostty/src/types/types.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

import '../helpers/wasm_binding_fixture.dart';

List<Object> fields(RawCellData cell) => [
  cell.contentTag,
  cell.codepoint,
  cell.hasGrapheme,
  cell.styleId,
  cell.wide,
  cell.isProtected,
  cell.hasHyperlink,
  cell.semanticContent,
  cell.hasBackgroundRgb,
  cell.backgroundR,
  cell.backgroundG,
  cell.backgroundB,
];

void main() {
  final fixture = WasmBindingFixture();
  setUpAll(fixture.load);
  tearDownAll(fixture.close);
  test('decodes mixed raw cells to authoritative getter values', () {
    final terminalBindings = WasmTerminalBindings(
      fixture.exports,
      fixture.layout,
    );
    final render = WasmRenderBindings(fixture.exports, fixture.layout);
    final terminal = terminalBindings.terminalNew(12, 1);
    final selectionBindings = WasmSelectionBindings(
      fixture.exports,
      fixture.layout,
    );
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
      expect(
        decoded.hasGrapheme,
        decoded.contentTag == CellContentTag.codepointGrapheme,
      );
      expect(
        decoded.hasBackgroundRgb,
        decoded.contentTag == CellContentTag.bgColorRgb,
      );
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

  test(
    'views remain independent across growth and refresh their logical contents',
    () {
      final terminals = WasmTerminalBindings(fixture.exports, fixture.layout);
      final render = WasmRenderBindings(fixture.exports, fixture.layout);
      final terminal = terminals.terminalNew(8, 2);
      final state = render.renderStateNew();
      final rows = render.rowIteratorNew();
      addTearDown(() {
        render.rowIteratorFree(rows);
        render.renderStateFree(state);
        terminals.terminalFree(terminal);
      });
      terminals.terminalVtWrite(
        terminal,
        Uint8List.fromList(
          utf8.encode('\x1b[48;2;4;5;6m\x1b[2J\x1b[HA\r\n\x1b[0mB'),
        ),
      );
      render.renderStateUpdate(state, terminal);
      render.rowIteratorInit(rows, state);
      final first = RawCellsView();
      final second = RawCellsView();
      expect(render.rowIteratorNext(rows), isTrue);
      expect(render.rowIteratorGetRawCells(rows, first), isTrue);
      final decoded = RawCellData();
      expect(render.decodeRawCell(first, 0, decoded), isTrue);
      final before = fields(decoded);
      expect(decoded.codepoint, 0x41);
      expect(render.rowIteratorNext(rows), isTrue);
      expect(render.rowIteratorGetRawCells(rows, second), isTrue);
      expect(render.decodeRawCell(second, 0, decoded), isTrue);
      expect(decoded.codepoint, 0x42);
      expect(render.decodeRawCell(first, 0, decoded), isTrue);
      expect(fields(decoded), before);

      (fixture.exports.memory as web.Memory).grow(1);
      expect(render.decodeRawCell(first, 0, decoded), isTrue);
      expect(fields(decoded), before);
      expect(render.decodeRawCell(second, 0, decoded), isTrue);
      expect(decoded.codepoint, 0x42);

      first.clear();
      expect(render.decodeRawCell(first, 0, decoded), isFalse);
      expect(render.decodeRawCell(first, -1, decoded), isFalse);
      terminals.terminalVtWrite(
        terminal,
        Uint8List.fromList(utf8.encode('\x1b[HZ')),
      );
      render.renderStateUpdate(state, terminal);
      render.rowIteratorInit(rows, state);
      expect(render.rowIteratorNext(rows), isTrue);
      expect(render.rowIteratorGetRawCells(rows, first), isTrue);
      expect(render.decodeRawCell(first, 0, decoded), isTrue);
      expect(decoded.codepoint, 0x5a);
      expect(render.decodeRawCell(first, first.length, decoded), isFalse);
      for (final width in [32, 4, 8]) {
        terminals.terminalResize(terminal, width, 2, 0, 0);
        terminals.terminalVtWrite(
          terminal,
          Uint8List.fromList(utf8.encode('\x1bcZ')),
        );
        render.renderStateUpdate(state, terminal);
        render.rowIteratorInit(rows, state);
        expect(render.rowIteratorNext(rows), isTrue);
        expect(render.rowIteratorGetRawCells(rows, first), isTrue);
        expect(first.length, width);
        expect(render.decodeRawCell(first, 0, decoded), isTrue);
        expect(decoded.codepoint, 0x5a);
        expect(render.decodeRawCell(first, width, decoded), isFalse);
      }
    },
  );
}

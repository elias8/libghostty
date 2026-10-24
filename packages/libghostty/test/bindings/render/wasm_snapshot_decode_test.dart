@Tags(['wasm'])
library;

import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:libghostty/src/bindings/render/wasm.dart';
import 'package:libghostty/src/bindings/terminal/wasm.dart';
import 'package:libghostty/src/bindings/types.dart';
import 'package:libghostty/src/bindings/wasm/memory.dart';
import 'package:libghostty/src/generated/libghostty_enums.g.dart';
import 'package:libghostty/src/types/types.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

import '../helpers/wasm_binding_fixture.dart';

void main() {
  final fixture = WasmBindingFixture();
  setUpAll(fixture.load);
  tearDownAll(fixture.close);

  for (final grow in [false, true]) {
    test('real module preserves exact styles after growth=$grow', () {
      final terminalBindings = WasmTerminalBindings(
        fixture.exports,
        fixture.layout,
      );
      final render = WasmRenderBindings(fixture.exports, fixture.layout);
      final terminal = terminalBindings.terminalNew(8, 1);
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
            'A\x1b[1;2;3;5;7;8;9;53m\x1b[4:3m'
            '\x1b[38;2;1;2;3m\x1b[48;2;4;5;6m\x1b[58;2;7;8;9mB'
            '\x1b[0;38;5;241;48;5;17;58;5;253mC',
          ),
        ),
      );
      render.renderStateUpdate(state, terminal);
      render.rowIteratorInit(rows, state);
      expect(render.rowIteratorNext(rows), isTrue);
      render.rowCellsInit(cells, rows);
      render.rowCellsSelect(cells, 0);
      expectStyle(render.rowCellsGetStyle(cells), const Style());
      if (grow) (fixture.exports.memory as web.Memory).grow(1);
      render.rowCellsSelect(cells, 1);
      expectStyle(
        render.rowCellsGetStyle(cells),
        const Style(
          bold: true,
          faint: true,
          italic: true,
          blink: true,
          inverse: true,
          invisible: true,
          overline: true,
          strikethrough: true,
          underline: SgrUnderline.curly,
          foreground: RgbColor(1, 2, 3),
          background: RgbColor(4, 5, 6),
          underlineColor: RgbColor(7, 8, 9),
        ),
      );
      render.rowCellsSelect(cells, 2);
      expectStyle(
        render.rowCellsGetStyle(cells),
        const Style(
          foreground: PaletteColor(241),
          background: PaletteColor(17),
          underlineColor: PaletteColor(253),
        ),
      );
    });

    test('real module preserves the full palette after growth=$grow', () {
      final terminalBindings = WasmTerminalBindings(
        fixture.exports,
        fixture.layout,
      );
      final render = WasmRenderBindings(fixture.exports, fixture.layout);
      final terminal = terminalBindings.terminalNew(8, 1);
      final state = render.renderStateNew();
      addTearDown(() {
        render.renderStateFree(state);
        terminalBindings.terminalFree(terminal);
      });
      final palette = [
        for (var i = 0; i < 256; i++) RgbColor(i, (3 * i) & 255, 255 - i),
      ];
      terminalBindings.terminalSetColorPalette(terminal, palette);
      terminalBindings.terminalSetColorForeground(
        terminal,
        const RgbColor(11, 22, 33),
      );
      terminalBindings.terminalSetColorBackground(
        terminal,
        const RgbColor(44, 55, 66),
      );
      terminalBindings.terminalSetColorCursor(
        terminal,
        const RgbColor(77, 88, 99),
      );
      render.renderStateUpdate(state, terminal);
      render.renderStateGetColors(state);
      if (grow) (fixture.exports.memory as web.Memory).grow(1);
      final colors = render.renderStateGetColors(state);
      expect(colors.foreground, const RgbColor(11, 22, 33));
      expect(colors.background, const RgbColor(44, 55, 66));
      expect(colors.cursor, const RgbColor(77, 88, 99));
      expect(colors.palette, orderedEquals(palette));
      terminalBindings.terminalSetColorCursor(terminal, null);
      render.renderStateUpdate(state, terminal);
      expect(render.renderStateGetColors(state).cursor, isNull);
    });
  }

  test('style export may grow memory before returning its output', () {
    final harness = FaultExports();
    final memory = Memory(harness.exports);
    final layout = fixture.layout;
    harness.object['ghostty_render_state_row_cells_get'] =
        (JSNumber _, JSNumber key, JSNumber output) {
          expect(key.toDartInt, RenderStateRowCellsData.style.value);
          final address = output.toDartInt;
          expect(memory.readU32(address), layout.styleSize);
          harness.memory.grow(1);
          memory.writeBytes(address, Uint8List(layout.styleSize));
          memory.writeU32(address, layout.styleSize);
          void color(int offset, StyleColorTag tag, int r, int g, int b) {
            memory.writeU32(address + offset, tag.value);
            memory.writeU8(address + offset + layout.styleColorR, r);
            memory.writeU8(address + offset + layout.styleColorG, g);
            memory.writeU8(address + offset + layout.styleColorB, b);
          }

          color(layout.styleFg, StyleColorTag.palette, 241, 0, 0);
          color(layout.styleBg, StyleColorTag.rgb, 4, 128, 255);
          color(layout.styleUnderlineColor, StyleColorTag.none, 0, 0, 0);
          memory.writeU8(address + layout.styleItalic, 1);
          memory.writeU8(address + layout.styleBlink, 1);
          memory.writeU8(address + layout.styleInvisible, 1);
          memory.writeU8(address + layout.styleOverline, 1);
          memory.writeI32(
            address + layout.styleUnderline,
            SgrUnderline.dashed.value,
          );
          return Result.success.value.toJS;
        }.toJS;
    final render = WasmRenderBindings(harness.exports, layout);
    expect(
      render.rowCellsGetStyle(const LibGhosttyHandle.fromAddress(64)),
      const Style(
        italic: true,
        blink: true,
        invisible: true,
        overline: true,
        underline: SgrUnderline.dashed,
        foreground: PaletteColor(241),
        background: RgbColor(4, 128, 255),
      ),
    );
  });

  for (final cursor in [false, true]) {
    test('palette export may grow before returning cursor=$cursor', () {
      final harness = FaultExports();
      final memory = Memory(harness.exports);
      final layout = fixture.layout;
      final expected = [
        for (var i = 0; i < 256; i++) RgbColor(255 - i, i, (i * 5) & 255),
      ];
      harness.object['ghostty_render_state_get'] =
          (JSNumber _, JSNumber key, JSNumber output) {
            expect(key.toDartInt, RenderStateData.colors.value);
            final address = output.toDartInt;
            expect(memory.readU32(address), layout.colorsSize);
            harness.memory.grow(1);
            memory.writeBytes(address, Uint8List(layout.colorsSize));
            memory.writeU32(address, layout.colorsSize);
            void rgb(int offset, RgbColor color) {
              memory.writeU8(address + offset + layout.colorRgbR, color.r);
              memory.writeU8(address + offset + layout.colorRgbG, color.g);
              memory.writeU8(address + offset + layout.colorRgbB, color.b);
            }

            rgb(layout.colorsFg, const RgbColor(13, 29, 47));
            rgb(layout.colorsBg, const RgbColor(61, 79, 101));
            rgb(layout.colorsCursor, const RgbColor(127, 151, 181));
            memory.writeU8(
              address + layout.colorsCursorHasValue,
              cursor ? 1 : 0,
            );
            for (var i = 0; i < 256; i++) {
              rgb(layout.colorsPalette + i * layout.colorRgbSize, expected[i]);
            }
            return Result.success.value.toJS;
          }.toJS;
      final render = WasmRenderBindings(harness.exports, layout);
      final colors = render.renderStateGetColors(
        const LibGhosttyHandle.fromAddress(64),
      );
      expect(colors.foreground, const RgbColor(13, 29, 47));
      expect(colors.background, const RgbColor(61, 79, 101));
      expect(colors.cursor, cursor ? const RgbColor(127, 151, 181) : null);
      expect(colors.palette, orderedEquals(expected));
    });
  }
}

void expectStyle(Style actual, Style expected) {
  Map<String, Object?> fields(Style style) => {
    'bold': style.bold,
    'italic': style.italic,
    'faint': style.faint,
    'blink': style.blink,
    'inverse': style.inverse,
    'invisible': style.invisible,
    'overline': style.overline,
    'strikethrough': style.strikethrough,
    'foreground': style.foreground,
    'background': style.background,
    'underline': style.underline,
    'underlineColor': style.underlineColor,
  };
  expect(fields(actual), fields(expected));
}

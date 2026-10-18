@Tags(['wasm'])
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:libghostty/src/bindings/render/wasm.dart';
import 'package:libghostty/src/bindings/types.dart';
import 'package:libghostty/src/bindings/wasm/layouts.dart';
import 'package:libghostty/src/bindings/wasm/memory.dart';
import 'package:libghostty/src/generated/libghostty_enums.g.dart';
import 'package:libghostty/src/types/types.dart';
import 'package:test/test.dart';

import '../helpers/wasm_binding_fixture.dart';

@JS('String')
external JSString _stringify(JSAny value);

void main() {
  final fixture = WasmBindingFixture();
  late Layouts layout;

  setUpAll(() async {
    await fixture.load();
    layout = fixture.layout;
  });

  tearDownAll(fixture.close);

  group('WasmRenderBindings', () {
    group('constructor', () {
      test('rolls back exact allocations and succeeds on retry', () {
        const construct = WasmRenderBindings.new;
        final baseline = FaultExports();

        construct(baseline.exports, layout);

        expect(baseline.allocations, isNotEmpty);

        for (var failure = 1; failure <= baseline.attempts; failure++) {
          final harness = FaultExports()..failAt = failure;

          expect(
            () => construct(harness.exports, layout),
            throwsA(isA<OutOfMemoryException>()),
          );
          expect(harness.frees, hasLength(failure - 1));
          expect(harness.frees, harness.allocations.reversed.toList());

          harness.failAt = null;
          harness.frees.clear();
          construct(harness.exports, layout);

          expect(harness.frees, isEmpty);
        }
      });
    });

    group('raw cell and row transport', () {
      test(
        'all raw producers preserve exact bits through single and multi calls',
        () {
          final harness = FaultExports();
          final memory = Memory(harness.exports);
          final captures = <String>[];

          void writeRaw(int address) {
            memory.writeU32(address, 0x0001f642);
            memory.writeU32(address + 4, 0x80000000);
          }

          JSNumber produce(JSNumber _, JSNumber out) {
            writeRaw(out.toDartInt);
            return 0.toJS;
          }

          harness.object['ghostty_grid_ref_cell'] = produce.toJS;
          harness.object['ghostty_grid_ref_row'] = produce.toJS;
          harness.object['ghostty_render_state_row_cells_get'] =
              (JSNumber _, JSNumber key, JSNumber out) {
                writeRaw(out.toDartInt);
                return 0.toJS;
              }.toJS;
          harness.object['ghostty_render_state_row_get'] =
              (JSNumber _, JSNumber key, JSNumber out) {
                writeRaw(out.toDartInt);
                return 0.toJS;
              }.toJS;

          JSNumber produceMany(
            JSNumber _,
            JSNumber count,
            JSNumber keys,
            JSNumber values,
            JSNumber written, {
            required bool row,
          }) {
            for (var i = 0; i < count.toDartInt; i++) {
              final key = memory.readU32(keys.toDartInt + i * 4);
              final out = memory.readPtr(values.toDartInt + i * 4);
              memory.writeU32(out, 0);
              memory.writeU32(out + 4, 0);
              if (key ==
                  (row
                      ? RenderStateRowData.raw.value
                      : RenderStateRowCellsData.raw.value)) {
                writeRaw(out);
              }
            }
            memory.writeU32(written.toDartInt, count.toDartInt);
            return 0.toJS;
          }

          harness.object['ghostty_render_state_row_cells_get_multi'] =
              ((JSNumber h, JSNumber n, JSNumber k, JSNumber v, JSNumber w) =>
                      produceMany(h, n, k, v, w, row: false))
                  .toJS;
          harness.object['ghostty_render_state_row_get_multi'] =
              ((JSNumber h, JSNumber n, JSNumber k, JSNumber v, JSNumber w) =>
                      produceMany(h, n, k, v, w, row: true))
                  .toJS;

          JSNumber capture(JSBigInt value) {
            captures.add(_stringify(value).toDart);
            return Result.invalidValue.value.toJS;
          }

          for (final domain in ['cell', 'row']) {
            harness.object['ghostty_${domain}_get'] =
                ((JSBigInt value, JSNumber _, JSNumber _) => capture(
                  value,
                )).toJS;
            harness.object['ghostty_${domain}_get_multi'] =
                ((
                      JSBigInt value,
                      JSNumber _,
                      JSNumber _,
                      JSNumber _,
                      JSNumber _,
                    ) => capture(value))
                    .toJS;
          }

          final bindings = WasmRenderBindings(harness.exports, layout);
          const handle = LibGhosttyHandle.fromAddress(64);
          const ref = (node: 64, x: 0, y: 0);
          final cells = [
            bindings.gridRefCell(ref),
            bindings.rowCellsGetRawCell(handle),
            bindings.rowCellsGetSummary(handle).rawCell,
          ];
          final rows = [
            bindings.gridRefRow(ref),
            bindings.rowIteratorGetRawRow(handle),
            bindings.rowIteratorGetSummary(handle).rawRow,
          ];

          for (final cell in cells) {
            expect(
              () => bindings.cellGetProtected(cell),
              throwsA(isA<InvalidValueException>()),
            );
            expect(
              () => bindings.cellGetSummary(cell),
              throwsA(isA<InvalidValueException>()),
            );
          }

          for (final row in rows) {
            expect(
              () => bindings.rowGetWrap(row),
              throwsA(isA<InvalidValueException>()),
            );
            expect(
              () => bindings.rowGetSummary(row),
              throwsA(isA<InvalidValueException>()),
            );
          }

          expect(captures, List<String>.filled(12, '9223372036854904386'));
        },
      );
    });
  });
}

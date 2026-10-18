@Tags(['wasm'])
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:libghostty/src/bindings/terminal/wasm.dart';
import 'package:libghostty/src/bindings/wasm/layouts.dart';
import 'package:libghostty/src/bindings/wasm/memory.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

import '../helpers/wasm_binding_fixture.dart';

void main() {
  final fixture = WasmBindingFixture();
  late Layouts layout;

  setUpAll(() async {
    await fixture.load();
    layout = fixture.layout;
  });

  tearDownAll(fixture.close);

  group('WasmTerminalBindings', () {
    group('terminalVtWrite', () {
      test('large terminal writes reuse storage and preserve bytes', () {
        final harness = FaultExports();
        harness.object['__indirect_function_table'] = web.Table(
          web.TableDescriptor(element: 'anyfunc', initial: 0),
        );
        final memory = Memory(harness.exports);
        final payload = Uint8List(128 * 1024)..last = 0x5a;
        var writes = 0;
        harness.object['ghostty_terminal_vt_write'] =
            (JSNumber _, JSNumber pointer, JSNumber length) {
              expect(
                memory.readBytes(pointer.toDartInt, length.toDartInt),
                payload,
              );
              writes++;
            }.toJS;
        final bindings = WasmTerminalBindings(harness.exports, layout);

        bindings.terminalVtWrite(const .fromAddress(7), payload);
        final allocations = harness.allocations.length;

        bindings.terminalVtWrite(const .fromAddress(7), payload);

        expect(writes, 2);
        expect(harness.allocations, hasLength(allocations));
        expect(harness.frees, isEmpty);
      });
    });
  });
}

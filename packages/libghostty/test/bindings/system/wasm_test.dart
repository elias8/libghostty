@Tags(['wasm'])
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:libghostty/src/bindings/system/wasm.dart';
import 'package:libghostty/src/bindings/wasm/adapter.dart';
import 'package:libghostty/src/bindings/wasm/layouts.dart';
import 'package:libghostty/src/bindings/wasm/memory.dart';
import 'package:libghostty/src/generated/libghostty_wasm.g.dart';
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

  group('WasmSystemBindings', () {
    group('sysSetRandomSecure', () {
      test('secure random callback writes bytes after memory growth', () {
        final wasmMemory = web.Memory(
          web.MemoryDescriptor(initial: 1, maximum: 2),
        );
        final table = web.Table(
          web.TableDescriptor(element: 'anyfunc', initial: 0),
        );
        final object = newJsObject()
          ..['memory'] = wasmMemory
          ..['__indirect_function_table'] = table;
        var callbackIndex = -1;
        object['ghostty_sys_set'] = (JSNumber _, JSNumber index) {
          callbackIndex = index.toDartInt;
          return 0.toJS;
        }.toJS;
        final memory = Memory(GhosttyExports(object));
        final bindings = WasmSystemBindings(GhosttyExports(object), layout);
        bindings.sysSetRandomSecure((bytes) {
          wasmMemory.grow(1);
          bytes.setAll(0, const [0x13, 0x37, 0xa5, 0x5a]);
          return true;
        });
        const output = 65536 - 4;

        final result =
            (table.get(callbackIndex)! as JSFunction).callAsFunction(
                  null,
                  0.toJS,
                  output.toJS,
                  4.toJS,
                )!
                as JSNumber;

        expect(result.toDartInt, 1);
        expect(memory.readBytes(output, 4), [0x13, 0x37, 0xa5, 0x5a]);
      });
    });
  });
}

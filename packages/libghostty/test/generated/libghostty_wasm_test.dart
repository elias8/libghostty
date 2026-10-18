@Tags(['wasm'])
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:libghostty/src/bindings/wasm/adapter.dart';
import 'package:libghostty/src/bindings/wasm/memory.dart';
import 'package:libghostty/src/generated/libghostty_wasm.g.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

@JS('BigInt')
external JSBigInt _bigInt(JSString value);

@JS('WebAssembly.instantiate')
external JSPromise _instantiate(JSArrayBuffer bytes, JSObject imports);

void main() {
  group('GhosttyExports', () {
    group('exact i64 transport', () {
      late GhosttyExports exports;
      late StreamChannel<Object?> assetChannel;

      setUpAll(() async {
        assetChannel = spawnHybridUri('/test/helpers/asset_server.dart');
        final portValue = await assetChannel.stream.first;
        if (portValue is! double) {
          throw StateError('Asset server returned no port.');
        }
        final port = portValue.toInt();
        final response = await web.window
            .fetch('http://localhost:$port/lib/src/wasm/libghostty.wasm'.toJS)
            .toDart;
        final env = newJsObject()..['log'] = ((JSNumber _, JSNumber _) {}).toJS;
        final imports = newJsObject()..['env'] = env;
        final result =
            (await _instantiate(
                  await response.arrayBuffer().toDart,
                  imports,
                ).toDart)!
                as JSObject;
        final instance = result['instance']! as JSObject;
        exports = GhosttyExports(instance['exports']! as JSObject);
      });

      tearDownAll(() => assetChannel.sink.close());

      test('actual exports retain bit 63 and supplementary codepoint bits', () {
        final memory = Memory(exports);
        final buffer = exports.ghostty_wasm_alloc(32);
        expect(buffer, isNot(0));
        try {
          final cell = _bigInt('9223372036855290120'.toJS);
          final row = _bigInt('9223372041149743104'.toJS);
          final keys = buffer;
          final values = buffer + 4;
          final written = buffer + 8;
          final out = buffer + 16;

          expect(exports.ghostty_cell_get(cell, 1, out), 0);
          expect(memory.readU32(out), 0x1f642);

          memory.writeU32(keys, 1);
          memory.writePtr(values, out);
          memory.writeU32(out, 0);
          memory.writeU32(written, 0);
          expect(
            exports.ghostty_cell_get_multi(cell, 1, keys, values, written),
            0,
          );
          expect(memory.readU32(written), 1);
          expect(memory.readU32(out), 0x1f642);

          expect(exports.ghostty_row_get(row, 1, out), 0);
          expect(memory.readU8(out), 1);

          memory.writeU8(out, 0);
          memory.writeU32(written, 0);
          expect(
            exports.ghostty_row_get_multi(row, 1, keys, values, written),
            0,
          );
          expect(memory.readU32(written), 1);
          expect(memory.readU8(out), 1);
        } finally {
          exports.ghostty_wasm_free(buffer, 32);
        }
      });
    });
  });
}

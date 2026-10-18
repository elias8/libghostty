@Tags(['wasm'])
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:libghostty/src/bindings/wasm/adapter.dart';
import 'package:libghostty/src/bindings/wasm/allocation_owner.dart';
import 'package:libghostty/src/generated/libghostty_wasm.g.dart';
import 'package:libghostty/src/types/exceptions.dart';
import 'package:test/test.dart';

void main() {
  group('WasmAllocationOwner', () {
    group('rollback', () {
      test('construction allocations roll back exactly and can be retried', () {
        var attempts = 0;
        var failAt = 3;
        final frees = <(int, int)>[];
        final exportsObject = newJsObject()
          ..['ghostty_wasm_alloc'] = ((JSNumber length) {
            attempts++;
            if (attempts == failAt) return 0.toJS;
            return (attempts * 32).toJS;
          }).toJS
          ..['ghostty_wasm_free'] = ((JSNumber pointer, JSNumber length) {
            frees.add((pointer.toDartInt, length.toDartInt));
          }).toJS;
        final exports = GhosttyExports(exportsObject);
        final failedOwner = WasmAllocationOwner(exports);

        failedOwner.allocate(11);
        failedOwner.allocate(19);
        expect(
          () => failedOwner.allocate(23),
          throwsA(isA<OutOfMemoryException>()),
        );
        failedOwner.rollback();

        expect(frees, [(64, 19), (32, 11)]);

        failAt = -1;
        final retryOwner = WasmAllocationOwner(exports);
        final first = retryOwner.allocate(7);
        final second = retryOwner.allocate(13);

        expect((first, second), (128, 160));

        retryOwner.commit();

        expect(frees, [(64, 19), (32, 11)]);
      });
    });
  });
}

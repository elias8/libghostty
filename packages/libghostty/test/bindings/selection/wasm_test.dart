@Tags(['wasm'])
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:libghostty/src/bindings/selection/wasm.dart';
import 'package:libghostty/src/bindings/wasm/layouts.dart';
import 'package:libghostty/src/bindings/wasm/memory.dart';
import 'package:libghostty/src/generated/libghostty_enums.g.dart';
import 'package:libghostty/src/types/types.dart';
import 'package:test/test.dart';

import '../helpers/wasm_binding_fixture.dart';

void main() {
  final fixture = WasmBindingFixture();
  late Layouts layout;

  setUpAll(() async {
    await fixture.load();
    layout = fixture.layout;
  });

  tearDownAll(fixture.close);

  group('WasmSelectionBindings', () {
    group('constructor', () {
      test('rolls back exact allocations and succeeds on retry', () {
        const construct = WasmSelectionBindings.new;
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

    group('terminalSelectionContains', () {
      test('selection partial OOM retains scratch and succeeds on retry', () {
        final harness = FaultExports();
        final memory = Memory(harness.exports);
        harness.object['ghostty_terminal_selection_contains'] =
            (JSNumber _, JSNumber _, JSNumber _, JSNumber out) {
              memory.writeU8(out.toDartInt, 1);
              return Result.success.value.toJS;
            }.toJS;
        final bindings = WasmSelectionBindings(harness.exports, layout);
        final constructorAllocations = harness.allocations.length;
        harness.failAt = harness.attempts + 2;
        const selection = (
          start: (node: 1, x: 2, y: 3),
          end: (node: 4, x: 5, y: 6),
          rectangle: false,
        );

        expect(
          () => bindings.terminalSelectionContains(
            const .fromAddress(7),
            selection,
            PointTag.screen,
            const Position(row: 8, col: 9),
          ),
          throwsA(isA<OutOfMemoryException>()),
        );
        expect(harness.frees, isEmpty);

        harness.failAt = null;
        expect(
          bindings.terminalSelectionContains(
            const .fromAddress(7),
            selection,
            PointTag.screen,
            const Position(row: 8, col: 9),
          ),
          isTrue,
        );
        expect(harness.allocations.length, constructorAllocations + 3);
        expect(harness.frees, isEmpty);
      });
    });
  });
}

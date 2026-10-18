@Tags(['wasm'])
library;

import 'package:libghostty/src/bindings/formatter/wasm.dart';
import 'package:libghostty/src/bindings/wasm/layouts.dart';
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

  group('WasmFormatterBindings', () {
    group('constructor', () {
      test('rolls back exact allocations and succeeds on retry', () {
        const construct = WasmFormatterBindings.new;
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
  });
}

@Tags(['wasm'])
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:libghostty/src/bindings/kitty_graphics/wasm.dart';
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

  group('WasmKittyGraphicsBindings', () {
    group('constructor', () {
      test('rolls back exact allocations and succeeds on retry', () {
        const construct = WasmKittyGraphicsBindings.new;
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

    group('kittyGraphicsGet', () {
      test('Kitty storage uses null only for noValue and preserves errors', () {
        final harness = FaultExports();
        final memory = Memory(harness.exports);
        var result = Result.noValue;
        harness.object['ghostty_terminal_get'] =
            (JSNumber _, JSNumber _, JSNumber out) {
              memory.writePtr(out.toDartInt, 128);
              return result.value.toJS;
            }.toJS;
        final bindings = WasmKittyGraphicsBindings(harness.exports, layout);

        expect(bindings.kittyGraphicsGet(const .fromAddress(64)), isNull);

        result = Result.invalidValue;
        expect(
          () => bindings.kittyGraphicsGet(const .fromAddress(64)),
          throwsA(isA<InvalidValueException>()),
        );

        result = Result.success;

        expect(bindings.kittyGraphicsGet(const .fromAddress(64))?.value, 128);
      });
    });

    group('kittyGraphicsImage', () {
      test('Kitty image lookup returns nullable handles for absent images', () {
        final harness = FaultExports();
        harness.object['ghostty_kitty_graphics_image'] =
            ((JSNumber _, JSNumber id) => (id.toDartInt == 42 ? 128 : 0).toJS)
                .toJS;
        final bindings = WasmKittyGraphicsBindings(harness.exports, layout);

        expect(bindings.kittyGraphicsImage(const .fromAddress(64), 99), isNull);
        expect(
          bindings.kittyGraphicsImage(const .fromAddress(64), 42)?.value,
          128,
        );
        expect(
          () => bindings.kittyGraphicsImage(const .fromAddress(0), 42),
          throwsA(isA<InvalidValueException>()),
        );
      });
    });
  });
}

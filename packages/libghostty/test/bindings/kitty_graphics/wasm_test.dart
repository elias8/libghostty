@Tags(['wasm'])
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

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
      test(
        'Kitty storage handles unavailable features and preserves errors',
        () {
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

          result = Result.unsupported;
          expect(bindings.kittyGraphicsGet(const .fromAddress(64)), isNull);

          result = Result.invalidValue;
          expect(
            () => bindings.kittyGraphicsGet(const .fromAddress(64)),
            throwsA(isA<InvalidValueException>()),
          );

          result = Result.success;

          expect(bindings.kittyGraphicsGet(const .fromAddress(64))?.value, 128);
        },
      );
    });

    test('reads pixel strings and propagates missing pixels', () {
      final harness = FaultExports();
      final memory = Memory(harness.exports);
      var result = Result.success;
      harness.object['ghostty_kitty_graphics_image_get'] =
          (JSNumber image, JSNumber data, JSNumber out) {
            expect(data.toDartInt, KittyGraphicsImageData.pixels.value);
            memory.writePtr(out.toDartInt + layout.stringPtr, 256);
            memory.writeU32(out.toDartInt + layout.stringLen, 3);
            return result.value.toJS;
          }.toJS;
      memory.writeBytes(256, Uint8List.fromList([255, 0, 42]));
      final bindings = WasmKittyGraphicsBindings(harness.exports, layout);
      final destination = Uint8List(3);
      expect(
        bindings.kittyGraphicsImageGetPixelData(
          const .fromAddress(64),
          destination,
        ),
        3,
      );
      expect(destination, [255, 0, 42]);
      expect(
        () => bindings.kittyGraphicsImageGetPixelData(
          const .fromAddress(64),
          Uint8List(2),
        ),
        throwsRangeError,
      );
      result = Result.noValue;
      expect(
        () => bindings.kittyGraphicsImageGetPixelData(
          const .fromAddress(64),
          destination,
        ),
        throwsA(isA<NoValueException>()),
      );
    });

    test('encodes each image layer as a bit mask', () {
      final harness = FaultExports();
      final memory = Memory(harness.exports);
      final masks = <int>[];
      harness.object['ghostty_kitty_graphics_placement_iterator_set'] =
          (JSNumber iterator, JSNumber option, JSNumber value) {
            expect(
              option.toDartInt,
              KittyGraphicsPlacementIteratorOption.layer.value,
            );
            masks.add(memory.readU32(value.toDartInt));
            return Result.success.value.toJS;
          }.toJS;
      final bindings = WasmKittyGraphicsBindings(harness.exports, layout);
      for (final layer in ImageLayer.values) {
        bindings.kittyGraphicsPlacementIteratorSetLayer(
          const .fromAddress(64),
          layer,
        );
      }
      expect(masks, [1, 2, 4]);
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

@Tags(['ffi'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flterm/src/rendering/kitty_image_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart';

void main() {
  group('KittyImageCache', () {
    Future<ui.Image> testImage() {
      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        Uint8List.fromList([0xff, 0xff, 0xff, 0xff]),
        1,
        1,
        ui.PixelFormat.rgba8888,
        completer.complete,
      );
      return completer.future;
    }

    group('dispose', () {
      test('clears ready entries', () async {
        final cache = KittyImageCache(onImageReady: () {});
        addTearDown(cache.dispose);
        final image = await testImage();
        cache.putReady(1, image);

        cache.dispose();

        expect(cache.lookupById(1), isNull);
      });

      test('allows repeated calls', () {
        final cache = KittyImageCache(onImageReady: () {});
        addTearDown(cache.dispose);
        cache.dispose();

        expect(cache.dispose, returnsNormally);
      });

      test('rejects lookup after disposal', () {
        final terminal = Terminal(cols: 1, rows: 1);
        addTearDown(terminal.dispose);
        terminal.write(
          Uint8List.fromList('\x1b_Gf=24,s=1,v=1,a=t,i=1;/wAA\x1b\\'.codeUnits),
        );
        final image = KittyGraphics.of(terminal)!.image(1)!;
        final cache = KittyImageCache(onImageReady: () {})..dispose();

        expect(() => cache.lookup(image), throwsStateError);
      });
    });

    group('lookup', () {
      Uint8List transmitPixel({required int id, required List<int> rgb}) {
        final payload = base64Encode(rgb);
        return Uint8List.fromList(
          '\x1b_Gf=24,s=1,v=1,a=t,i=$id;$payload\x1b\\'.codeUnits,
        );
      }

      void applyImagePressure(
        KittyImageCache cache,
        Terminal terminal, {
        required int firstId,
        required int lastId,
      }) {
        for (var imageId = firstId; imageId <= lastId; imageId++) {
          terminal.write(transmitPixel(id: imageId, rgb: [imageId, 0, 0]));
          cache.lookup(KittyGraphics.of(terminal)!.image(imageId)!);
          cache.evict({1, imageId});
        }
      }

      late Terminal terminal;

      setUp(() {
        terminal = Terminal(cols: 4, rows: 2)..kittyImageStorageLimit = 1 << 20;
      });

      tearDown(() {
        terminal.dispose();
      });

      test('retries pixels after progressive snapshot restoration', () async {
        terminal.write(transmitPixel(id: 7, rgb: [0xff, 0x00, 0x00]));
        final decoder = SnapshotDecoder(terminal.encodeSnapshot());
        addTearDown(decoder.dispose);
        final restored = decoder.ready();
        addTearDown(restored.dispose);
        final callbacks = <ui.ImageDecoderCallback>[];
        final cache = KittyImageCache(
          onImageReady: () {},
          decodeImage: (_, _, _, _, callback) => callbacks.add(callback),
        );
        addTearDown(cache.dispose);
        final graphics = KittyGraphics.of(restored)!;
        final pending = graphics.image(7)!;
        final generation = pending.generation;

        expect(cache.lookup(pending), isA<KittyImagePending>());
        expect(cache.lookup(pending), isA<KittyImagePending>());
        expect(callbacks, isEmpty);

        while (decoder.next() != null) {}
        final completed = graphics.image(7)!;
        expect(completed.generation, generation);
        expect(cache.lookup(completed), isA<KittyImagePending>());
        expect(callbacks, hasLength(1));
        final decoded = await testImage();
        callbacks.single(decoded);
        expect((cache.lookupById(7)! as KittyImageReady).image, same(decoded));
      });

      test(
        'retains prior ready image during valid replacement decode',
        () async {
          final callbacks = <ui.ImageDecoderCallback>[];
          final cache = KittyImageCache(
            onImageReady: () {},
            decodeImage: (_, _, _, _, callback) => callbacks.add(callback),
          );
          addTearDown(cache.dispose);
          terminal.write(transmitPixel(id: 7, rgb: [0xff, 0x00, 0x00]));
          final firstImage = KittyGraphics.of(terminal)!.image(7)!;
          cache.lookup(firstImage);
          final firstDecoded = await testImage();
          callbacks.single(firstDecoded);
          final previous = cache.lookupById(7);

          terminal.write(transmitPixel(id: 7, rgb: [0x00, 0xff, 0x00]));
          final replacement = KittyGraphics.of(terminal)!.image(7)!;
          cache.lookup(replacement);

          final current = cache.lookupById(7);

          expect(current, same(previous));
        },
      );

      test(
        'publishes the newest generation after a stale decode completes',
        () async {
          final callbacks = <ui.ImageDecoderCallback>[];
          final cache = KittyImageCache(
            onImageReady: () {},
            decodeImage: (_, _, _, _, callback) => callbacks.add(callback),
          );
          addTearDown(cache.dispose);
          terminal.write(transmitPixel(id: 8, rgb: [0xff, 0x00, 0x00]));
          final firstImage = KittyGraphics.of(terminal)!.image(8)!;
          cache.lookup(firstImage);
          terminal.write(transmitPixel(id: 8, rgb: [0x00, 0xff, 0x00]));
          final replacement = KittyGraphics.of(terminal)!.image(8)!;
          cache.lookup(replacement);
          final firstDecoded = await testImage();
          final replacementDecoded = await testImage();

          callbacks.single(firstDecoded);
          callbacks.last(replacementDecoded);

          final entry = cache.lookupById(8)! as KittyImageReady;

          expect(entry.image, same(replacementDecoded));
        },
      );

      test('publishes a replacement after its decode completes', () async {
        final callbacks = <ui.ImageDecoderCallback>[];
        final cache = KittyImageCache(
          onImageReady: () {},
          decodeImage: (_, _, _, _, callback) => callbacks.add(callback),
        );
        addTearDown(cache.dispose);
        terminal.write(transmitPixel(id: 9, rgb: [0xff, 0x00, 0x00]));
        final firstImage = KittyGraphics.of(terminal)!.image(9)!;
        cache.lookup(firstImage);
        callbacks.single(await testImage());
        terminal.write(transmitPixel(id: 9, rgb: [0x00, 0xff, 0x00]));
        final replacement = KittyGraphics.of(terminal)!.image(9)!;
        cache.lookup(replacement);
        final replacementDecoded = await testImage();

        callbacks.last(replacementDecoded);

        final entry = cache.lookupById(9)! as KittyImageReady;

        expect(entry.image, same(replacementDecoded));
      });

      test('reuses a ready image for an unchanged generation', () async {
        final callbacks = <ui.ImageDecoderCallback>[];
        final cache = KittyImageCache(
          onImageReady: () {},
          decodeImage: (_, _, _, _, callback) => callbacks.add(callback),
        );
        addTearDown(cache.dispose);
        terminal.write(transmitPixel(id: 13, rgb: [0xff, 0x00, 0x00]));
        final image = KittyGraphics.of(terminal)!.image(13)!;
        cache.lookup(image);
        callbacks.single(await testImage());
        final ready = cache.lookupById(13);

        final reused = cache.lookup(image);

        expect(reused, same(ready));
      });

      test('expands RGB channels in Flutter pixel order', () {
        late Uint8List decodedPixels;
        final cache = KittyImageCache(
          onImageReady: () {},
          decodeImage: (pixels, _, _, _, _) => decodedPixels = pixels,
        );
        addTearDown(cache.dispose);
        terminal.write(transmitPixel(id: 24, rgb: [0x12, 0x34, 0x56]));

        cache.lookup(KittyGraphics.of(terminal)!.image(24)!);

        expect(decodedPixels, [0x12, 0x34, 0x56, 0xff]);
      });

      test('expands every RGB pixel without crossing channel boundaries', () {
        late Uint8List decodedPixels;
        final cache = KittyImageCache(
          onImageReady: () {},
          decodeImage: (pixels, _, _, _, _) => decodedPixels = pixels,
        );
        addTearDown(cache.dispose);
        final rgb = [
          0x12,
          0x34,
          0x56,
          0x78,
          0x9a,
          0xbc,
          0xde,
          0xf0,
          0x11,
          0x22,
          0x33,
          0x44,
          0x55,
          0x66,
          0x77,
        ];
        terminal.write(
          Uint8List.fromList(
            '\x1b_Gf=24,s=5,v=1,a=t,i=25;${base64Encode(rgb)}\x1b\\'.codeUnits,
          ),
        );

        cache.lookup(KittyGraphics.of(terminal)!.image(25)!);

        expect(decodedPixels, [
          0x12,
          0x34,
          0x56,
          0xff,
          0x78,
          0x9a,
          0xbc,
          0xff,
          0xde,
          0xf0,
          0x11,
          0xff,
          0x22,
          0x33,
          0x44,
          0xff,
          0x55,
          0x66,
          0x77,
          0xff,
        ]);
      });

      test('reuses RGB expansion storage after decode completion', () async {
        final callbacks = <ui.ImageDecoderCallback>[];
        final decodedPixels = <Uint8List>[];
        final cache = KittyImageCache(
          onImageReady: () {},
          decodeImage: (pixels, _, _, _, callback) {
            decodedPixels.add(pixels);
            callbacks.add(callback);
          },
        );
        addTearDown(cache.dispose);
        terminal.write(transmitPixel(id: 27, rgb: [0x10, 0x20, 0x30]));
        cache.lookup(KittyGraphics.of(terminal)!.image(27)!);
        terminal.write(transmitPixel(id: 28, rgb: [0x40, 0x50, 0x60]));
        cache.lookup(KittyGraphics.of(terminal)!.image(28)!);

        callbacks.single(await testImage());

        expect(decodedPixels, hasLength(2));
        expect(decodedPixels.last, same(decodedPixels.first));
        expect(decodedPixels.last, [0x40, 0x50, 0x60, 0xff]);
      });

      test('bounds concurrent decodes while newer images arrive', () {
        final callbacks = <ui.ImageDecoderCallback>[];
        final cache = KittyImageCache(
          onImageReady: () {},
          decodeImage: (_, _, _, _, callback) => callbacks.add(callback),
        );
        addTearDown(cache.dispose);
        terminal.write(transmitPixel(id: 14, rgb: [0xff, 0x00, 0x00]));
        cache.lookup(KittyGraphics.of(terminal)!.image(14)!);
        terminal.write(transmitPixel(id: 15, rgb: [0x00, 0xff, 0x00]));

        cache.lookup(KittyGraphics.of(terminal)!.image(15)!);

        expect(callbacks, hasLength(1));
      });

      test(
        'continues queued decoding when readiness notification throws',
        () async {
          final callbacks = <ui.ImageDecoderCallback>[];
          final cache = KittyImageCache(
            onImageReady: () => throw StateError('notification failed'),
            decodeImage: (_, _, _, _, callback) => callbacks.add(callback),
          );
          addTearDown(cache.dispose);
          terminal.write(transmitPixel(id: 25, rgb: [0x10, 0x00, 0x00]));
          cache.lookup(KittyGraphics.of(terminal)!.image(25)!);
          terminal.write(transmitPixel(id: 26, rgb: [0x20, 0x00, 0x00]));
          cache.lookup(KittyGraphics.of(terminal)!.image(26)!);

          final decoded = await testImage();

          expect(() => callbacks.single(decoded), throwsStateError);

          expect(callbacks, hasLength(2));
        },
      );

      test('skips a queued image evicted before decoding', () async {
        final callbacks = <ui.ImageDecoderCallback>[];
        final decodedRedChannels = <int>[];
        final cache = KittyImageCache(
          onImageReady: () {},
          decodeImage: (pixels, _, _, _, callback) {
            decodedRedChannels.add(pixels.first);
            callbacks.add(callback);
          },
        );
        addTearDown(cache.dispose);
        terminal.write(transmitPixel(id: 16, rgb: [0x10, 0x00, 0x00]));
        cache.lookup(KittyGraphics.of(terminal)!.image(16)!);
        terminal.write(transmitPixel(id: 17, rgb: [0x20, 0x00, 0x00]));
        cache.lookup(KittyGraphics.of(terminal)!.image(17)!);
        terminal.write(transmitPixel(id: 18, rgb: [0x30, 0x00, 0x00]));
        cache.lookup(KittyGraphics.of(terminal)!.image(18)!);
        cache.evict({16, 18});

        callbacks.single(await testImage());

        expect(decodedRedChannels, [0x10, 0x30]);
      });

      test(
        'coalesces sustained changing-ID pressure to the latest frame',
        () async {
          final callbacks = <ui.ImageDecoderCallback>[];
          final decodedRedChannels = <int>[];
          final cache = KittyImageCache(
            onImageReady: () {},
            decodeImage: (pixels, _, _, _, callback) {
              decodedRedChannels.add(pixels.first);
              callbacks.add(callback);
            },
          );
          addTearDown(cache.dispose);
          terminal.write(transmitPixel(id: 1, rgb: [1, 0, 0]));
          cache.lookup(KittyGraphics.of(terminal)!.image(1)!);
          applyImagePressure(cache, terminal, firstId: 2, lastId: 120);

          callbacks.single(await testImage());

          expect(decodedRedChannels, [1, 120]);
        },
      );

      test('does not let a refreshed image starve queued work', () async {
        final callbacks = <ui.ImageDecoderCallback>[];
        final decodedRedChannels = <int>[];
        final cache = KittyImageCache(
          onImageReady: () {},
          decodeImage: (pixels, _, _, _, callback) {
            decodedRedChannels.add(pixels.first);
            callbacks.add(callback);
          },
        );
        addTearDown(cache.dispose);
        terminal.write(transmitPixel(id: 19, rgb: [0x10, 0x00, 0x00]));
        cache.lookup(KittyGraphics.of(terminal)!.image(19)!);
        terminal.write(transmitPixel(id: 20, rgb: [0x20, 0x00, 0x00]));
        cache.lookup(KittyGraphics.of(terminal)!.image(20)!);
        terminal.write(transmitPixel(id: 21, rgb: [0x30, 0x00, 0x00]));
        cache.lookup(KittyGraphics.of(terminal)!.image(21)!);
        terminal.write(transmitPixel(id: 20, rgb: [0x40, 0x00, 0x00]));
        cache.lookup(KittyGraphics.of(terminal)!.image(20)!);

        callbacks.single(await testImage());

        expect(decodedRedChannels, [0x10, 0x30]);
      });

      test('pre-decoded image removes its queued request', () async {
        final callbacks = <ui.ImageDecoderCallback>[];
        final cache = KittyImageCache(
          onImageReady: () {},
          decodeImage: (_, _, _, _, callback) => callbacks.add(callback),
        );
        addTearDown(cache.dispose);
        terminal.write(transmitPixel(id: 22, rgb: [0x10, 0x00, 0x00]));
        cache.lookup(KittyGraphics.of(terminal)!.image(22)!);
        terminal.write(transmitPixel(id: 23, rgb: [0x20, 0x00, 0x00]));
        cache.lookup(KittyGraphics.of(terminal)!.image(23)!);
        final preDecoded = await testImage();
        cache.putReady(23, preDecoded);

        callbacks.single(await testImage());

        expect(callbacks, hasLength(1));
      });

      test(
        'does not republish a decode that completes after disposal',
        () async {
          final callbacks = <ui.ImageDecoderCallback>[];
          final cache = KittyImageCache(
            onImageReady: () {},
            decodeImage: (_, _, _, _, callback) => callbacks.add(callback),
          );
          addTearDown(cache.dispose);
          terminal.write(transmitPixel(id: 10, rgb: [0xff, 0x00, 0x00]));
          final image = KittyGraphics.of(terminal)!.image(10)!;
          cache.lookup(image);
          final decoded = await testImage();

          cache.dispose();
          callbacks.single(decoded);

          expect(cache.lookupById(10), isNull);
        },
      );

      test(
        'ignores an evicted decode after the same generation is requested',
        () async {
          final callbacks = <ui.ImageDecoderCallback>[];
          final cache = KittyImageCache(
            onImageReady: () {},
            decodeImage: (_, _, _, _, callback) => callbacks.add(callback),
          );
          addTearDown(cache.dispose);
          terminal.write(transmitPixel(id: 11, rgb: [0xff, 0x00, 0x00]));
          final image = KittyGraphics.of(terminal)!.image(11)!;
          cache.lookup(image);
          cache.evict({});
          cache.lookup(image);
          final evicted = await testImage();

          callbacks.first(evicted);

          expect(cache.lookupById(11), isA<KittyImagePending>());
        },
      );

      test('discards stale pending decode after generation changes', () async {
        final callbacks = <ui.ImageDecoderCallback>[];
        final cache = KittyImageCache(
          onImageReady: () {},
          decodeImage: (_, _, _, _, callback) {
            callbacks.add(callback);
          },
        );
        addTearDown(cache.dispose);
        final stale = await testImage();
        terminal.write(transmitPixel(id: 8, rgb: [0xff, 0x00, 0x00]));
        final staleImage = KittyGraphics.of(terminal)!.image(8)!;
        cache.lookup(staleImage);
        terminal.write(transmitPixel(id: 8, rgb: [0x00, 0xff, 0x00]));
        final currentImage = KittyGraphics.of(terminal)!.image(8)!;
        cache.lookup(currentImage);

        callbacks[0](stale);

        expect(cache.lookupById(8), isA<KittyImagePending>());
      });

      test('retries an image after the decoder throws synchronously', () {
        var decodeCalls = 0;
        final cache = KittyImageCache(
          onImageReady: () {},
          decodeImage: (_, _, _, _, _) {
            decodeCalls++;
            throw StateError('decode failed');
          },
        );
        addTearDown(cache.dispose);
        terminal.write(transmitPixel(id: 12, rgb: [0xff, 0x00, 0x00]));
        final image = KittyGraphics.of(terminal)!.image(12)!;

        expect(() => cache.lookup(image), throwsStateError);
        expect(() => cache.lookup(image), throwsStateError);

        expect(decodeCalls, 2);
      });
    });
  });
}

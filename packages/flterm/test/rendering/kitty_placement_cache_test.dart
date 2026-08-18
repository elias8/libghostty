@Tags(['ffi'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui'
    show Image, ImageDecoderCallback, Rect, Size, decodeImageFromPixels;

import 'package:flterm/src/foundation/cell_metrics.dart';
import 'package:flterm/src/foundation/terminal_theme.dart';
import 'package:flterm/src/rendering/kitty_image_cache.dart';
import 'package:flterm/src/rendering/kitty_placement_cache.dart';
import 'package:flterm/src/rendering/paint_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart';

void main() {
  group('KittyPlacementCache', () {
    const metrics = CellMetrics(cellWidth: 8, cellHeight: 16, baseline: 12);

    void writePlacedImage(
      Terminal terminal, {
      int id = 11,
      int width = 1,
      int columns = 1,
      int? placementId,
    }) {
      final payload = base64Encode(
        List<int>.generate(width * 3, (index) => index.isEven ? 0xff : 0),
      );
      final placement = placementId == null ? '' : ',p=$placementId';
      terminal.write(
        Uint8List.fromList(
          '\x1b_Gf=24,s=$width,v=1,a=T,i=$id$placement,c=$columns,r=1;'
                  '$payload\x1b\\'
              .codeUnits,
        ),
      );
    }

    void writeUnicodePlacements(Terminal terminal) {
      final pixels = base64Encode([0xff, 0x00, 0x00]);
      terminal.write(
        Uint8List.fromList(
          utf8.encode(
            '\x1b_Ga=T,t=d,f=24,i=23,s=1,v=1,C=1,U=1;'
            '$pixels\x1b\\'
            '\x1b[2;4H'
            '\x1b[38;2;0;0;23m'
            '\u{10EEEE}\u0305\u0305'
            'x'
            '\u{10EEEE}\u0305\u0305'
            '\x1b[39m',
          ),
        ),
      );
    }

    Future<Image> testImage() {
      final completer = Completer<Image>();
      decodeImageFromPixels(
        Uint8List.fromList([0xff, 0xff, 0xff, 0xff]),
        1,
        1,
        .rgba8888,
        completer.complete,
      );
      return completer.future;
    }

    ({
      List<ImageDecoderCallback> decodeCallbacks,
      KittyImageCache images,
      KittyPlacementCache placements,
      PaintState state,
      Terminal terminal,
    })
    geometryFixture() {
      final decodeCallbacks = <ImageDecoderCallback>[];
      final terminal = Terminal(cols: 8, rows: 2)
        ..kittyImageStorageLimit = 1 << 20;
      final state = PaintState(TerminalTheme.dark(), metrics)
        ..cols = 8
        ..rows = 2;
      final images = KittyImageCache(
        onImageReady: () {},
        decodeImage: (_, _, _, _, callback) => decodeCallbacks.add(callback),
      );
      final placements = KittyPlacementCache(state: state, images: images);
      writePlacedImage(terminal);
      terminal.resize(cols: 8, rows: 2, cellWidthPx: 8, cellHeightPx: 16);
      placements.sync(terminal, geometryDirty: true);
      return (
        decodeCallbacks: decodeCallbacks,
        images: images,
        placements: placements,
        state: state,
        terminal: terminal,
      );
    }

    late Terminal terminal;
    late PaintState state;
    late KittyImageCache images;
    late KittyPlacementCache placements;

    setUp(() {
      terminal = Terminal(cols: 8, rows: 2)..kittyImageStorageLimit = 1 << 20;
      state = PaintState(TerminalTheme.dark(), metrics)
        ..cols = 8
        ..rows = 2;
      images = KittyImageCache(onImageReady: () {});
      placements = KittyPlacementCache(state: state, images: images);
      writePlacedImage(terminal);
      placements.sync(terminal, geometryDirty: false);
    });

    tearDown(() {
      images.dispose();
      terminal.dispose();
    });

    group('sync', () {
      test(
        'renders discontinuous Unicode placements away from their definition',
        () {
          final unicodeTerminal = Terminal(cols: 8, rows: 3)
            ..kittyImageStorageLimit = 1 << 20;
          final unicodeState = PaintState(TerminalTheme.dark(), metrics)
            ..cols = 8
            ..rows = 3;
          final unicodeImages = KittyImageCache(onImageReady: () {});
          final unicodePlacements = KittyPlacementCache(
            state: unicodeState,
            images: unicodeImages,
          );
          addTearDown(unicodeImages.dispose);
          addTearDown(unicodeTerminal.dispose);
          unicodeTerminal.resize(
            cols: 8,
            rows: 3,
            cellWidthPx: 8,
            cellHeightPx: 16,
          );
          writeUnicodePlacements(unicodeTerminal);

          unicodePlacements.sync(unicodeTerminal, geometryDirty: true);

          expect(unicodePlacements.snapshots, hasLength(2));
          expect(unicodePlacements.snapshots.map((snapshot) => snapshot.dst), [
            const Rect.fromLTWH(24, 20, 8, 8),
            const Rect.fromLTWH(40, 20, 8, 8),
          ]);
          expect(unicodePlacements.snapshots.map((snapshot) => snapshot.src), [
            const Rect.fromLTWH(0, 0, 1, 1),
            const Rect.fromLTWH(0, 0, 1, 1),
          ]);
        },
      );

      test('returns false when generation and geometry are unchanged', () {
        final rebuilt = placements.sync(terminal, geometryDirty: false);

        expect(rebuilt, isFalse);
      });

      test('returns true when geometry changes', () {
        state.devicePixelRatio = 2.0;

        final rebuilt = placements.sync(terminal, geometryDirty: false);

        expect(rebuilt, isTrue);
      });

      test('refreshes destination geometry after a physical resize', () async {
        final fixture = geometryFixture();
        addTearDown(fixture.images.dispose);
        addTearDown(fixture.terminal.dispose);
        fixture.decodeCallbacks.single(await testImage());
        fixture.placements.sync(fixture.terminal, geometryDirty: false);
        fixture.state.metrics = const CellMetrics(
          cellWidth: 16,
          cellHeight: 32,
          baseline: 24,
        );
        fixture.terminal.resize(
          cols: 8,
          rows: 2,
          cellWidthPx: 16,
          cellHeightPx: 32,
        );
        fixture.placements.sync(fixture.terminal, geometryDirty: true);

        expect(
          fixture.placements.snapshots.single.dst.size,
          const Size(16, 32),
        );
      });

      test('does not request another decode after a physical resize', () {
        final fixture = geometryFixture();
        addTearDown(fixture.images.dispose);
        addTearDown(fixture.terminal.dispose);
        fixture.state.metrics = const CellMetrics(
          cellWidth: 16,
          cellHeight: 32,
          baseline: 24,
        );
        fixture.terminal.resize(
          cols: 8,
          rows: 2,
          cellWidthPx: 16,
          cellHeightPx: 32,
        );

        fixture.placements.sync(fixture.terminal, geometryDirty: true);

        expect(fixture.decodeCallbacks, hasLength(1));
      });

      test('removes snapshots hidden by terminal scrolling', () {
        terminal.write(Uint8List.fromList('\x1b[2;1H\n'.codeUnits));

        placements.sync(terminal, geometryDirty: true);

        expect(placements.snapshots, isEmpty);
      });

      test('keeps an incomplete chunked transmission non-drawable', () async {
        final callbacks = <ImageDecoderCallback>[];
        final chunkedTerminal = Terminal(cols: 8, rows: 2)
          ..kittyImageStorageLimit = 1 << 20;
        final chunkedState = PaintState(TerminalTheme.dark(), metrics)
          ..cols = 8
          ..rows = 2;
        final chunkedImages = KittyImageCache(
          onImageReady: () {},
          decodeImage: (_, _, _, _, callback) => callbacks.add(callback),
        );
        final chunkedPlacements = KittyPlacementCache(
          state: chunkedState,
          images: chunkedImages,
        );
        addTearDown(chunkedImages.dispose);
        addTearDown(chunkedTerminal.dispose);
        chunkedTerminal.resize(
          cols: 8,
          rows: 2,
          cellWidthPx: 8,
          cellHeightPx: 16,
        );
        chunkedTerminal.write(
          Uint8List.fromList(
            '\x1b_Ga=t,f=24,s=1,v=2,i=31,m=1;/wAA\x1b\\'
                    '\x1b_Ga=p,i=31,c=1,r=1\x1b\\'
                .codeUnits,
          ),
        );
        expect(
          () => chunkedPlacements.sync(chunkedTerminal, geometryDirty: true),
          returnsNormally,
        );
        expect(chunkedPlacements.snapshots, isEmpty);

        chunkedTerminal.write(
          Uint8List.fromList('\x1b_Gm=0;AP8A\x1b\\'.codeUnits),
        );
        chunkedTerminal.write(
          Uint8List.fromList('\x1b_Ga=p,i=31,c=1,r=1\x1b\\'.codeUnits),
        );
        chunkedPlacements.sync(chunkedTerminal, geometryDirty: true);
        callbacks.single(await testImage());
        chunkedPlacements.sync(chunkedTerminal, geometryDirty: true);

        expect(chunkedPlacements.snapshots, hasLength(1));
        expect(chunkedImages.lookupById(31), isA<KittyImageReady>());
      });

      test(
        'retains a complete frame while compatible replacement decodes',
        () async {
          final callbacks = <ImageDecoderCallback>[];
          final controlledImages = KittyImageCache(
            onImageReady: () {},
            decodeImage: (_, _, _, _, callback) => callbacks.add(callback),
          );
          final controlledPlacements = KittyPlacementCache(
            state: state,
            images: controlledImages,
          );
          addTearDown(controlledImages.dispose);
          terminal.resize(cols: 8, rows: 2, cellWidthPx: 8, cellHeightPx: 16);
          controlledPlacements.sync(terminal, geometryDirty: true);
          callbacks.single(await testImage());

          terminal.write(
            Uint8List.fromList('\x1b_Ga=d,d=I,i=11\x1b\\'.codeUnits),
          );
          terminal.write(Uint8List.fromList('\x1b[1;1H'.codeUnits));
          writePlacedImage(terminal, id: 12);
          controlledPlacements.sync(terminal, geometryDirty: true);
          final whilePending =
              controlledPlacements.snapshots.firstOrNull?.imageId;
          final oldReadyWhilePending =
              controlledImages.lookupById(11) is KittyImageReady;
          callbacks.last(await testImage());

          controlledPlacements.sync(terminal, geometryDirty: false);

          expect(whilePending, 11);
          expect(oldReadyWhilePending, isTrue);
          expect(controlledPlacements.snapshots.single.imageId, 12);
          expect(controlledImages.lookupById(11), isNull);
        },
      );

      test(
        'retains same-id pixels while compatible replacement decodes',
        () async {
          final callbacks = <ImageDecoderCallback>[];
          final controlledImages = KittyImageCache(
            onImageReady: () {},
            decodeImage: (_, _, _, _, callback) => callbacks.add(callback),
          );
          final controlledPlacements = KittyPlacementCache(
            state: state,
            images: controlledImages,
          );
          addTearDown(controlledImages.dispose);
          terminal.resize(cols: 8, rows: 2, cellWidthPx: 8, cellHeightPx: 16);
          controlledPlacements.sync(terminal, geometryDirty: true);
          callbacks.single(await testImage());
          controlledPlacements.sync(terminal, geometryDirty: false);
          final original = controlledPlacements.snapshots.single;

          terminal.write(Uint8List.fromList('\x1b[1;1H'.codeUnits));
          writePlacedImage(terminal);
          controlledPlacements.sync(terminal, geometryDirty: true);

          expect(controlledPlacements.snapshots.single, same(original));

          callbacks.last(await testImage());
          controlledPlacements.sync(terminal, geometryDirty: false);

          expect(
            controlledPlacements.snapshots.single.imageGeneration,
            isNot(original.imageGeneration),
          );
        },
      );

      test(
        'does not pair stale pixels with same-id replacement geometry',
        () async {
          final callbacks = <ImageDecoderCallback>[];
          final controlledImages = KittyImageCache(
            onImageReady: () {},
            decodeImage: (_, _, _, _, callback) => callbacks.add(callback),
          );
          final controlledPlacements = KittyPlacementCache(
            state: state,
            images: controlledImages,
          );
          addTearDown(controlledImages.dispose);
          terminal.resize(cols: 8, rows: 2, cellWidthPx: 8, cellHeightPx: 16);
          controlledPlacements.sync(terminal, geometryDirty: true);
          callbacks.single(await testImage());
          controlledPlacements.sync(terminal, geometryDirty: false);
          final original = controlledPlacements.snapshots.single;

          writePlacedImage(terminal, width: 2, columns: 2);
          controlledPlacements.sync(terminal, geometryDirty: true);

          final replacement = controlledPlacements.snapshots.single;
          final staleImage =
              controlledImages.lookupById(11)! as KittyImageReady;
          expect(original.dst.width, metrics.cellWidth);
          expect(replacement.dst.width, 2 * metrics.cellWidth);
          expect(staleImage.generation, isNot(replacement.imageGeneration));

          callbacks.last(await testImage());
          controlledPlacements.sync(terminal, geometryDirty: false);

          expect(
            controlledPlacements.snapshots.single.dst.width,
            2 * metrics.cellWidth,
          );
        },
      );

      test(
        'retains compatible multi-image geometry when replacement ids reorder',
        () async {
          final callbacks = <ImageDecoderCallback>[];
          final multiTerminal = Terminal(cols: 8, rows: 2)
            ..kittyImageStorageLimit = 1 << 20;
          final multiState = PaintState(TerminalTheme.dark(), metrics)
            ..cols = 8
            ..rows = 2;
          final controlledImages = KittyImageCache(
            onImageReady: () {},
            decodeImage: (_, _, _, _, callback) => callbacks.add(callback),
          );
          final controlledPlacements = KittyPlacementCache(
            state: multiState,
            images: controlledImages,
          );
          addTearDown(controlledImages.dispose);
          addTearDown(multiTerminal.dispose);
          multiTerminal.resize(
            cols: 8,
            rows: 2,
            cellWidthPx: 8,
            cellHeightPx: 16,
          );
          writePlacedImage(multiTerminal, placementId: 11);
          multiTerminal.write(Uint8List.fromList('\x1b[1;2H'.codeUnits));
          writePlacedImage(multiTerminal, id: 12, placementId: 12);
          controlledPlacements.sync(multiTerminal, geometryDirty: true);
          callbacks[0](await testImage());
          callbacks[1](await testImage());
          controlledPlacements.sync(multiTerminal, geometryDirty: false);

          multiTerminal.write(
            Uint8List.fromList(
              '\x1b_Ga=d,d=I,i=11\x1b\\\x1b_Ga=d,d=I,i=12\x1b\\'.codeUnits,
            ),
          );
          multiTerminal.write(Uint8List.fromList('\x1b[1;1H'.codeUnits));
          writePlacedImage(multiTerminal, id: 20, placementId: 20);
          multiTerminal.write(Uint8List.fromList('\x1b[1;2H'.codeUnits));
          writePlacedImage(multiTerminal, id: 10, placementId: 10);

          controlledPlacements.sync(multiTerminal, geometryDirty: true);

          expect(
            controlledPlacements.snapshots.map((snapshot) => snapshot.imageId),
            [11, 12],
          );
        },
      );

      test('orders equal-z placements by ascending image id', () {
        final equalZTerminal = Terminal(cols: 8, rows: 4)
          ..kittyImageStorageLimit = 1 << 20;
        final equalZState = PaintState(TerminalTheme.dark(), metrics)
          ..cols = 8
          ..rows = 4;
        final equalZImages = KittyImageCache(onImageReady: () {});
        final equalZPlacements = KittyPlacementCache(
          state: equalZState,
          images: equalZImages,
        );
        addTearDown(equalZImages.dispose);
        addTearDown(equalZTerminal.dispose);
        final payload = base64Encode([0xff, 0x00, 0x00]);

        equalZTerminal.write(
          Uint8List.fromList(
            '\x1b_Gf=24,s=1,v=1,a=T,i=2,p=1,c=1,r=1;$payload\x1b\\'.codeUnits,
          ),
        );
        equalZTerminal.write(
          Uint8List.fromList(
            '\x1b_Gf=24,s=1,v=1,a=T,i=11,p=1,c=1,r=1;$payload\x1b\\'.codeUnits,
          ),
        );
        equalZTerminal.write(
          Uint8List.fromList(
            '\x1b_Gf=24,s=1,v=1,a=T,i=13,p=1,c=1,r=1;$payload\x1b\\'.codeUnits,
          ),
        );
        equalZTerminal.resize(
          cols: 8,
          rows: 4,
          cellWidthPx: 8,
          cellHeightPx: 16,
        );

        equalZPlacements.sync(equalZTerminal, geometryDirty: true);

        expect(equalZPlacements.snapshots.map((snapshot) => snapshot.imageId), [
          2,
          11,
          13,
        ]);
      });
    });
  });
}

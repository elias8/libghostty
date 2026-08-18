@Tags(['ffi'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

import '../../helpers/setup.dart';

void main() {
  setUp(() => testEnvironment);

  group('Terminal', () {
    group('kittyGraphics', () {
      late Terminal terminal;

      setUp(() {
        terminal = Terminal(cols: 80, rows: 24);
        terminal.kittyImageStorageLimit = 1 << 20;
      });

      tearDown(() {
        terminal.dispose();
      });

      test('returns a handle when enabled at build time', () {
        expect(KittyGraphics.of(terminal), isNotNull);
      });

      group('image', () {
        test('returns null for an unknown id', () {
          expect(KittyGraphics.of(terminal)?.image(99999), isNull);
        });

        test('returns metadata after transmit APC', () {
          terminal.write(_transmitRedPixel());

          final image = KittyGraphics.of(terminal)?.image(42);
          expect(image, isNotNull);
          expect(image!.id, 42);
          expect(image.width, 1);
          expect(image.height, 1);
          expect(image.format, KittyImageFormat.rgb);
        });

        test('copies decoded RGB bytes', () {
          terminal.write(_transmitRedPixel(id: 7));
          final destination = Uint8List(3);

          final image = KittyGraphics.of(terminal)!.image(7)!;
          image.copyPixelDataInto(destination);

          expect(destination, [0xff, 0x00, 0x00]);
        });

        test('returns the copied RGB byte count', () {
          terminal.write(_transmitRedPixel(id: 8));
          final destination = Uint8List.fromList([1, 1, 1, 1]);

          final written = KittyGraphics.of(
            terminal,
          )!.image(8)!.copyPixelDataInto(destination);

          expect(written, 3);
        });

        test('keeps copied RGB bytes stable after terminal mutation', () {
          terminal.write(_transmitRedPixel(id: 8));
          final destination = Uint8List(3);
          KittyGraphics.of(terminal)!.image(8)!.copyPixelDataInto(destination);

          terminal.write(_transmitRedPixel(id: 9));

          expect(destination, [0xff, 0x00, 0x00]);
        });

        test('rejects insufficient pixel destination storage', () {
          terminal.write(_transmitRedPixel(id: 9));
          final image = KittyGraphics.of(terminal)!.image(9)!;
          final destination = Uint8List.fromList([1, 2]);

          expect(() => image.copyPixelDataInto(destination), throwsRangeError);
          expect(destination, [1, 2]);
        });
      });

      group('setApcBufferLimit', () {
        test('rejects oversized payloads', () {
          terminal.setApcBufferLimit(1);

          terminal.write(_transmitRedPixel(id: 8));

          expect(KittyGraphics.of(terminal)!.image(8), isNull);
        });

        test('restores default limit when cleared', () {
          terminal.setApcBufferLimit(1);
          terminal.setApcBufferLimit(null);

          terminal.write(_transmitRedPixel(id: 9));

          expect(KittyGraphics.of(terminal)!.image(9), isNotNull);
        });
      });

      group('setKittyApcBufferLimit', () {
        test('rejects oversized payloads', () {
          terminal.setKittyApcBufferLimit(1);

          terminal.write(_transmitRedPixel(id: 10));

          expect(KittyGraphics.of(terminal)!.image(10), isNull);
        });

        test('restores default limit when cleared', () {
          terminal.setKittyApcBufferLimit(1);
          terminal.setKittyApcBufferLimit(null);

          terminal.write(_transmitRedPixel(id: 11));

          expect(KittyGraphics.of(terminal)!.image(11), isNotNull);
        });
      });
    });
  });

  group('LibGhostty', () {
    group('setPngDecoder', () {
      late Terminal terminal;

      setUp(() {
        terminal = Terminal(cols: 80, rows: 24);
        terminal.kittyImageStorageLimit = 1 << 20;
      });

      tearDown(() {
        terminal.dispose();
        LibGhostty.clearPngDecoder();
      });

      test('uses callback result for PNG payload', () {
        final pngBytesSeen = <Uint8List>[];
        LibGhostty.setPngDecoder((bytes) {
          pngBytesSeen.add(Uint8List.fromList(bytes));
          return DecodedImage(
            width: 2,
            height: 1,
            rgba: Uint8List.fromList([
              0xff,
              0x00,
              0x00,
              0xff,
              0x00,
              0xff,
              0x00,
              0xff,
            ]),
          );
        });

        terminal.write(
          Uint8List.fromList('\x1b_Gf=100,a=t,i=55;aGVsbG8=\x1b\\'.codeUnits),
        );

        expect(pngBytesSeen, hasLength(1));
        final image = KittyGraphics.of(terminal)!.image(55);
        expect(image, isNotNull);
        expect(image!.width, 2);
        expect(image.height, 1);
        expect(image.format, KittyImageFormat.rgba);
        expect(image.copyPixelDataInto(Uint8List(8)), 8);
      });

      test('rejects payload when callback returns null', () {
        LibGhostty.setPngDecoder((_) => null);

        terminal.write(
          Uint8List.fromList('\x1b_Gf=100,a=t,i=56;aGVsbG8=\x1b\\'.codeUnits),
        );

        expect(KittyGraphics.of(terminal)!.image(56), isNull);
      });

      test('rejects payload when callback throws', () {
        LibGhostty.setPngDecoder((_) {
          throw StateError('decoder failed');
        });

        terminal.write(
          Uint8List.fromList('\x1b_Gf=100,a=t,i=58;aGVsbG8=\x1b\\'.codeUnits),
        );

        expect(KittyGraphics.of(terminal)!.image(58), isNull);
      });

      test('rejects payload when callback returns short RGBA data', () {
        LibGhostty.setPngDecoder(
          (_) => DecodedImage(width: 1, height: 1, rgba: Uint8List(3)),
        );

        terminal.write(
          Uint8List.fromList('\x1b_Gf=100,a=t,i=59;aGVsbG8=\x1b\\'.codeUnits),
        );

        expect(KittyGraphics.of(terminal)!.image(59), isNull);
      });

      test('rejects payload when callback returns oversized RGBA data', () {
        LibGhostty.setPngDecoder(
          (_) => DecodedImage(width: 1, height: 1, rgba: Uint8List(5)),
        );

        terminal.write(
          Uint8List.fromList('\x1b_Gf=100,a=t,i=60;aGVsbG8=\x1b\\'.codeUnits),
        );

        expect(KittyGraphics.of(terminal)!.image(60), isNull);
      });

      test('rejects payload with mismatched dimensions', () {
        LibGhostty.setPngDecoder(
          (_) => DecodedImage(width: 2, height: 1, rgba: Uint8List(4)),
        );

        terminal.write(
          Uint8List.fromList('\x1b_Gf=100,a=t,i=61;aGVsbG8=\x1b\\'.codeUnits),
        );

        expect(KittyGraphics.of(terminal)!.image(61), isNull);
      });

      test('clearPngDecoder stops routing to callback', () {
        var called = 0;
        LibGhostty.setPngDecoder((_) {
          called++;
          return DecodedImage(width: 1, height: 1, rgba: Uint8List(4));
        });
        LibGhostty.clearPngDecoder();

        terminal.write(
          Uint8List.fromList('\x1b_Gf=100,a=t,i=57;aGVsbG8=\x1b\\'.codeUnits),
        );
        expect(called, 0);
        expect(KittyGraphics.of(terminal)!.image(57), isNull);
      });
    });
  });

  group('KittyGraphics', () {
    group('placements', () {
      late Terminal terminal;

      setUp(() {
        terminal = Terminal(cols: 80, rows: 24);
        terminal.kittyImageStorageLimit = 1 << 20;
      });

      tearDown(() {
        terminal.dispose();
      });

      test('returns empty list when no placements exist', () {
        expect(KittyGraphics.of(terminal)?.placements(), isEmpty);
      });

      test('captures placement emitted by transmit and display APC', () {
        terminal.write(
          Uint8List.fromList(
            '\x1b_Gf=24,s=1,v=1,a=T,i=11,c=2,r=1;/wAA\x1b\\'.codeUnits,
          ),
        );

        final placements = KittyGraphics.of(terminal)!.placements();
        expect(placements, hasLength(1));
        final p = placements.single;
        expect(p.imageId, 11);
        expect(p.isVirtual, isFalse);
        expect(p.renderInfo.viewportVisible, isTrue);
        expect(p.renderInfo.viewportCol, 0);
        expect(p.renderInfo.viewportRow, 0);
        expect(p.renderInfo.gridCols, 2);
        expect(p.renderInfo.gridRows, 1);
        expect(p.renderInfo.sourceWidth, 1);
        expect(p.renderInfo.sourceHeight, 1);
      });

      test('keeps a placement snapshot stable after terminal mutation', () {
        terminal.resize(cols: 80, rows: 24, cellWidthPx: 10, cellHeightPx: 20);
        terminal.write(
          Uint8List.fromList(
            '\x1b_Gf=24,s=1,v=1,a=T,i=12,c=2,r=1;/wAA\x1b\\'.codeUnits,
          ),
        );
        final placement = KittyGraphics.of(terminal)!.placements().single;
        final snapshot = (
          imageId: placement.imageId,
          placementId: placement.placementId,
          isVirtual: placement.isVirtual,
          xOffset: placement.xOffset,
          yOffset: placement.yOffset,
          sourceX: placement.sourceX,
          sourceY: placement.sourceY,
          sourceWidth: placement.sourceWidth,
          sourceHeight: placement.sourceHeight,
          columns: placement.columns,
          rows: placement.rows,
          z: placement.z,
          renderInfo: placement.renderInfo,
        );

        terminal.resize(cols: 80, rows: 24, cellWidthPx: 20, cellHeightPx: 40);

        expect((
          imageId: placement.imageId,
          placementId: placement.placementId,
          isVirtual: placement.isVirtual,
          xOffset: placement.xOffset,
          yOffset: placement.yOffset,
          sourceX: placement.sourceX,
          sourceY: placement.sourceY,
          sourceWidth: placement.sourceWidth,
          sourceHeight: placement.sourceHeight,
          columns: placement.columns,
          rows: placement.rows,
          z: placement.z,
          renderInfo: placement.renderInfo,
        ), snapshot);
      });

      test(
        'reports a negative viewport row for a partially scrolled placement',
        () {
          final scrolled = Terminal(cols: 80, rows: 5);
          addTearDown(scrolled.dispose);
          scrolled.kittyImageStorageLimit = 1 << 20;
          scrolled.resize(cols: 80, rows: 5, cellWidthPx: 10, cellHeightPx: 20);
          scrolled.write(
            Uint8List.fromList(
              '\x1b_Ga=t,t=d,f=24,i=13,s=1,v=2;////////\x1b\\'
                      '\x1b_Ga=p,i=13,p=1,c=1,r=4,C=1;\x1b\\'
                  .codeUnits,
            ),
          );
          scrolled.write(Uint8List.fromList('\n\n\n\n\n\n'.codeUnits));

          final placement = KittyGraphics.of(scrolled)!.placements().single;

          expect(
            (
              placement.renderInfo.viewportVisible,
              placement.renderInfo.viewportRow,
            ),
            (true, -2),
          );
        },
      );

      test('clamps destination to an intersected source rectangle', () {
        terminal.resize(cols: 80, rows: 24, cellWidthPx: 10, cellHeightPx: 20);
        final payload = base64Encode(Uint8List(64));
        terminal.write(
          Uint8List.fromList(
            '\x1b_Ga=t,t=d,f=32,i=14,s=4,v=4;$payload\x1b\\'.codeUnits,
          ),
        );
        terminal.write(
          Uint8List.fromList(
            '\x1b_Ga=p,i=14,p=1,x=3,y=3,w=10,h=10;\x1b\\'.codeUnits,
          ),
        );

        final renderInfo = KittyGraphics.of(
          terminal,
        )!.placements().single.renderInfo;

        expect(
          (
            renderInfo.pixelWidth,
            renderInfo.pixelHeight,
            renderInfo.sourceX,
            renderInfo.sourceY,
            renderInfo.sourceWidth,
            renderInfo.sourceHeight,
          ),
          (1, 1, 3, 3, 1, 1),
        );
      });
    });

    group('unicodePlacements', () {
      late Terminal terminal;

      setUp(() {
        terminal = Terminal(cols: 8, rows: 2);
        terminal.kittyImageStorageLimit = 1 << 20;
        terminal.resize(cols: 8, rows: 2, cellWidthPx: 8, cellHeightPx: 16);
      });

      tearDown(() {
        terminal.dispose();
      });

      test('returns empty list when no Unicode placements exist', () {
        expect(KittyGraphics.of(terminal)?.unicodePlacements(), isEmpty);
      });

      test('decodes Unicode placement metadata', () {
        terminal.write(_unicodePlacement());

        final placement = KittyGraphics.of(terminal)!.unicodePlacements().first;

        expect(
          (
            placement.topLeft,
            placement.imageId,
            placement.placementId,
            placement.column,
            placement.row,
            placement.columns,
            placement.rows,
          ),
          (const Position(row: 0, col: 0), 3, 0, 0, 0, 1, 1),
        );
      });

      test('resolves drawable Unicode placement geometry', () {
        terminal.write(_unicodePlacement());

        final info = KittyGraphics.of(
          terminal,
        )!.unicodePlacements().first.renderInfo!;

        expect(
          (
            info.viewportCol,
            info.viewportRow,
            info.pixelWidth,
            info.pixelHeight,
          ),
          (0, 0, 8, 8),
        );
      });

      test('retains copied values after terminal mutation', () {
        terminal.write(_unicodePlacement());

        final placement = KittyGraphics.of(terminal)!.unicodePlacements().first;

        terminal.resize(cols: 8, rows: 2, cellWidthPx: 16, cellHeightPx: 32);

        expect(
          (placement.topLeft, placement.renderInfo!.pixelWidth),
          (const Position(row: 0, col: 0), 8),
        );
      });

      test('returns null render geometry for an unresolved occurrence', () {
        terminal.write(_unicodePlaceholderOnly());

        final placement = KittyGraphics.of(terminal)!.unicodePlacements().first;

        expect(placement.renderInfo, isNull);
      });
    });
  });
}

Uint8List _transmitRedPixel({int id = 42}) {
  return Uint8List.fromList(
    '\x1b_Gf=24,s=1,v=1,a=t,i=$id;/wAA\x1b\\'.codeUnits,
  );
}

Uint8List _unicodePlacement() {
  return Uint8List.fromList(
    utf8.encode(
      '\x1b_Ga=T,t=d,f=24,i=3,s=1,v=1,C=1,U=1;'
      '/wAA\x1b\\'
      '\x1b[38;2;0;0;3m'
      '\u{10EEEE}\u0305\u0305'
      '\x1b[39m',
    ),
  );
}

Uint8List _unicodePlaceholderOnly() {
  return Uint8List.fromList(
    utf8.encode('\x1b[38;2;0;0;3m\u{10EEEE}\u0305\u0305\x1b[39m'),
  );
}

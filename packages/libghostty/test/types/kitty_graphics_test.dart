import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

void main() {
  group('KittyPlacementRenderInfo', () {
    KittyPlacementRenderInfo create({int pixelWidth = 16}) =>
        KittyPlacementRenderInfo(
          pixelWidth: pixelWidth,
          pixelHeight: 32,
          gridCols: 2,
          gridRows: 2,
          viewportCol: -1,
          viewportRow: 3,
          viewportVisible: true,
          sourceX: 1,
          sourceY: 2,
          sourceWidth: 8,
          sourceHeight: 16,
        );

    group('offscreen', () {
      test('has no visible geometry', () {
        const info = KittyPlacementRenderInfo.offscreen();

        expect(info.viewportVisible, isFalse);
        expect(info.pixelWidth, 0);
        expect(info.pixelHeight, 0);
        expect(info.gridCols, 0);
        expect(info.gridRows, 0);
      });
    });

    group('equality', () {
      test('compares equal values structurally', () {
        final first = create();
        final second = create();

        expect(first, second);
      });

      test('produces equal hashes for equal values', () {
        final first = create();
        final second = create();

        expect(first.hashCode, second.hashCode);
      });

      test('distinguishes changed values', () {
        final first = create();
        final second = create(pixelWidth: 17);

        expect(first, isNot(second));
      });
    });
  });

  group('KittyPlacement', () {
    KittyPlacement create({int imageId = 42}) => KittyPlacement(
      imageId: imageId,
      placementId: 7,
      isVirtual: false,
      xOffset: 1,
      yOffset: 2,
      sourceX: 3,
      sourceY: 4,
      sourceWidth: 5,
      sourceHeight: 6,
      columns: 2,
      rows: 3,
      z: -1,
      renderInfo: const KittyPlacementRenderInfo.offscreen(),
    );

    group('equality', () {
      test('compares equal values structurally', () {
        final first = create();
        final second = create();

        expect(first, second);
      });

      test('produces equal hashes for equal values', () {
        final first = create();
        final second = create();

        expect(first.hashCode, second.hashCode);
      });

      test('distinguishes changed values', () {
        final first = create();
        final second = create(imageId: 43);

        expect(first, isNot(second));
      });
    });
  });

  group('KittyUnicodePlacementRenderInfo', () {
    KittyUnicodePlacementRenderInfo create({int pixelWidth = 16}) =>
        KittyUnicodePlacementRenderInfo(
          viewportCol: -1,
          viewportRow: 3,
          z: -1,
          cellOffsetX: 1,
          cellOffsetY: 2,
          pixelWidth: pixelWidth,
          pixelHeight: 32,
          sourceX: 3,
          sourceY: 4,
          sourceWidth: 5,
          sourceHeight: 6,
        );

    group('equality', () {
      test('compares equal values structurally', () {
        final first = create();
        final second = create();

        expect(first, second);
      });

      test('produces equal hashes for equal values', () {
        final first = create();
        final second = create();

        expect(first.hashCode, second.hashCode);
      });

      test('distinguishes changed values', () {
        final first = create();
        final second = create(pixelWidth: 17);

        expect(first, isNot(second));
      });
    });
  });

  group('KittyUnicodePlacement', () {
    KittyUnicodePlacement create({int imageId = 42}) => KittyUnicodePlacement(
      topLeft: const Position(row: 0, col: 1),
      imageId: imageId,
      placementId: 7,
      column: 1,
      row: 2,
      columns: 3,
      rows: 1,
      renderInfo: const KittyUnicodePlacementRenderInfo(
        viewportCol: 4,
        viewportRow: 5,
        z: -1,
        cellOffsetX: 6,
        cellOffsetY: 7,
        pixelWidth: 8,
        pixelHeight: 9,
        sourceX: 10,
        sourceY: 11,
        sourceWidth: 12,
        sourceHeight: 13,
      ),
    );

    group('equality', () {
      test('compares equal values structurally', () {
        final first = create();
        final second = create();

        expect(first, second);
      });

      test('produces equal hashes for equal values', () {
        final first = create();
        final second = create();

        expect(first.hashCode, second.hashCode);
      });

      test('distinguishes changed values', () {
        final first = create();
        final second = create(imageId: 43);

        expect(first, isNot(second));
      });

      test('allows missing render geometry', () {
        const placement = KittyUnicodePlacement(
          topLeft: Position(row: 0, col: 0),
          imageId: 1,
          placementId: 2,
          column: 3,
          row: 4,
          columns: 5,
          rows: 1,
        );

        expect(placement.renderInfo, isNull);
      });
    });
  });
}

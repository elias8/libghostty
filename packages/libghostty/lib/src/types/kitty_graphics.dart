import 'package:meta/meta.dart';

import 'geometry.dart';

/// Snapshot of a single Kitty graphics placement.
///
/// The placement fields and [renderInfo] are copied while the native iterator
/// is positioned, so this value remains valid after iteration finishes. Image
/// pixel data is separate and must be resolved through the Kitty graphics
/// storage while its borrowed handle remains valid.
@immutable
final class KittyPlacement {
  /// Image id this placement references.
  final int imageId;

  /// Placement id assigned by the protocol, or zero when none was supplied.
  final int placementId;

  /// Whether this is a virtual Unicode placeholder placement.
  ///
  /// Virtual placements do not participate in normal placement rendering.
  final bool isVirtual;

  /// Pixel offset from the left edge of the anchor cell.
  final int xOffset;

  /// Pixel offset from the top edge of the anchor cell.
  final int yOffset;

  /// Requested source rectangle x origin in pixels.
  final int sourceX;

  /// Requested source rectangle y origin in pixels.
  final int sourceY;

  /// Requested source rectangle width in pixels, or zero for the full image.
  final int sourceWidth;

  /// Requested source rectangle height in pixels, or zero for the full image.
  final int sourceHeight;

  /// Requested number of grid columns, or zero to derive it from image size.
  final int columns;

  /// Requested number of grid rows, or zero to derive it from image size.
  final int rows;

  /// Z-index controlling compositing order.
  ///
  /// Negative values draw below text and non-negative values draw above text.
  final int z;

  /// Resolved rendering geometry at the time of capture.
  final KittyPlacementRenderInfo renderInfo;

  const KittyPlacement({
    required this.imageId,
    required this.placementId,
    required this.isVirtual,
    required this.xOffset,
    required this.yOffset,
    required this.sourceX,
    required this.sourceY,
    required this.sourceWidth,
    required this.sourceHeight,
    required this.columns,
    required this.rows,
    required this.z,
    required this.renderInfo,
  });

  @override
  int get hashCode => Object.hash(
    imageId,
    placementId,
    isVirtual,
    xOffset,
    yOffset,
    sourceX,
    sourceY,
    sourceWidth,
    sourceHeight,
    columns,
    rows,
    z,
    renderInfo,
  );

  @override
  bool operator ==(Object other) =>
      other is KittyPlacement &&
      other.imageId == imageId &&
      other.placementId == placementId &&
      other.isVirtual == isVirtual &&
      other.xOffset == xOffset &&
      other.yOffset == yOffset &&
      other.sourceX == sourceX &&
      other.sourceY == sourceY &&
      other.sourceWidth == sourceWidth &&
      other.sourceHeight == sourceHeight &&
      other.columns == columns &&
      other.rows == rows &&
      other.z == z &&
      other.renderInfo == renderInfo;
}

/// Resolved rendering geometry for a Kitty graphics placement.
///
/// This combines rendered pixel size, grid extent, viewport-relative
/// position, and the source rectangle returned by libghostty. When
/// [viewportVisible] is false, the placement is fully off-screen or virtual,
/// and [viewportCol] and [viewportRow] are not meaningful.
@immutable
final class KittyPlacementRenderInfo {
  /// Rendered width in pixels.
  final int pixelWidth;

  /// Rendered height in pixels.
  final int pixelHeight;

  /// Number of grid columns occupied by the placement.
  final int gridCols;

  /// Number of grid rows occupied by the placement.
  final int gridRows;

  /// Viewport-relative column of the placement's top-left corner.
  ///
  /// This may be negative for a partially visible placement.
  final int viewportCol;

  /// Viewport-relative row of the placement's top-left corner.
  ///
  /// This may be negative for a partially visible placement.
  final int viewportRow;

  /// Whether the placement is at least partially visible in the viewport.
  final bool viewportVisible;

  /// Resolved source rectangle x origin in pixels, clamped to image bounds.
  final int sourceX;

  /// Resolved source rectangle y origin in pixels, clamped to image bounds.
  final int sourceY;

  /// Resolved source rectangle width in pixels.
  final int sourceWidth;

  /// Resolved source rectangle height in pixels.
  final int sourceHeight;

  const KittyPlacementRenderInfo({
    required this.pixelWidth,
    required this.pixelHeight,
    required this.gridCols,
    required this.gridRows,
    required this.viewportCol,
    required this.viewportRow,
    required this.viewportVisible,
    required this.sourceX,
    required this.sourceY,
    required this.sourceWidth,
    required this.sourceHeight,
  });

  /// Creates the value used when a placement has no visible render geometry.
  const KittyPlacementRenderInfo.offscreen()
    : pixelWidth = 0,
      pixelHeight = 0,
      gridCols = 0,
      gridRows = 0,
      viewportCol = 0,
      viewportRow = 0,
      viewportVisible = false,
      sourceX = 0,
      sourceY = 0,
      sourceWidth = 0,
      sourceHeight = 0;

  @override
  int get hashCode => Object.hash(
    pixelWidth,
    pixelHeight,
    gridCols,
    gridRows,
    viewportCol,
    viewportRow,
    viewportVisible,
    sourceX,
    sourceY,
    sourceWidth,
    sourceHeight,
  );

  @override
  bool operator ==(Object other) =>
      other is KittyPlacementRenderInfo &&
      other.pixelWidth == pixelWidth &&
      other.pixelHeight == pixelHeight &&
      other.gridCols == gridCols &&
      other.gridRows == gridRows &&
      other.viewportCol == viewportCol &&
      other.viewportRow == viewportRow &&
      other.viewportVisible == viewportVisible &&
      other.sourceX == sourceX &&
      other.sourceY == sourceY &&
      other.sourceWidth == sourceWidth &&
      other.sourceHeight == sourceHeight;
}

/// Snapshot of one decoded Kitty Unicode placement occurrence.
@immutable
final class KittyUnicodePlacement {
  /// Viewport-relative position of the occurrence's first cell.
  final Position topLeft;

  /// Image id referenced by the occurrence.
  final int imageId;

  /// Placement id assigned by the protocol, or zero when absent.
  final int placementId;

  /// Zero-based source-grid column.
  final int column;

  /// Zero-based source-grid row.
  final int row;

  /// Number of columns in this occurrence.
  final int columns;

  /// Number of rows in this occurrence.
  final int rows;

  /// Resolved rendering geometry, or null when the occurrence is not drawable.
  final KittyUnicodePlacementRenderInfo? renderInfo;

  const KittyUnicodePlacement({
    required this.topLeft,
    required this.imageId,
    required this.placementId,
    required this.column,
    required this.row,
    required this.columns,
    required this.rows,
    this.renderInfo,
  });

  @override
  int get hashCode => Object.hash(
    topLeft,
    imageId,
    placementId,
    column,
    row,
    columns,
    rows,
    renderInfo,
  );

  @override
  bool operator ==(Object other) =>
      other is KittyUnicodePlacement &&
      other.topLeft == topLeft &&
      other.imageId == imageId &&
      other.placementId == placementId &&
      other.column == column &&
      other.row == row &&
      other.columns == columns &&
      other.rows == rows &&
      other.renderInfo == renderInfo;
}

/// Resolved rendering geometry for a Kitty Unicode placement occurrence.
@immutable
final class KittyUnicodePlacementRenderInfo {
  /// Viewport-relative destination column.
  final int viewportCol;

  /// Viewport-relative destination row.
  final int viewportRow;

  /// Effective z-index used for the placement.
  final int z;

  /// Destination x offset from the cell origin in physical pixels.
  final int cellOffsetX;

  /// Destination y offset from the cell origin in physical pixels.
  final int cellOffsetY;

  /// Destination width in physical pixels.
  final int pixelWidth;

  /// Destination height in physical pixels.
  final int pixelHeight;

  /// Source rectangle x origin in image pixels.
  final int sourceX;

  /// Source rectangle y origin in image pixels.
  final int sourceY;

  /// Source rectangle width in image pixels.
  final int sourceWidth;

  /// Source rectangle height in image pixels.
  final int sourceHeight;

  const KittyUnicodePlacementRenderInfo({
    required this.viewportCol,
    required this.viewportRow,
    required this.z,
    required this.cellOffsetX,
    required this.cellOffsetY,
    required this.pixelWidth,
    required this.pixelHeight,
    required this.sourceX,
    required this.sourceY,
    required this.sourceWidth,
    required this.sourceHeight,
  });

  @override
  int get hashCode => Object.hash(
    viewportCol,
    viewportRow,
    z,
    cellOffsetX,
    cellOffsetY,
    pixelWidth,
    pixelHeight,
    sourceX,
    sourceY,
    sourceWidth,
    sourceHeight,
  );

  @override
  bool operator ==(Object other) =>
      other is KittyUnicodePlacementRenderInfo &&
      other.viewportCol == viewportCol &&
      other.viewportRow == viewportRow &&
      other.z == z &&
      other.cellOffsetX == cellOffsetX &&
      other.cellOffsetY == cellOffsetY &&
      other.pixelWidth == pixelWidth &&
      other.pixelHeight == pixelHeight &&
      other.sourceX == sourceX &&
      other.sourceY == sourceY &&
      other.sourceWidth == sourceWidth &&
      other.sourceHeight == sourceHeight;
}

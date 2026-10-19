import 'dart:math';
import 'dart:ui';

import 'atlas_budget.dart';
import 'atlas_entry.dart';

/// Owns atlas storage, slot allocation, and image replacement.
class AtlasTexture {
  static const defaultInitialSize = 256;
  static const defaultMaxSize = 4096;

  // Gap between atlas cells prevents sub-pixel bleed between sprites.
  static const padding = 1.0;

  final int _initialSize;
  final int _maxSize;
  final AtlasBudget? _budget;
  var _chargedBytes = 0;

  late int _width;
  late int _height;
  var _packX = 0.0;
  var _packY = 0.0;
  var _rowHeight = 0.0;
  var _slabLeft = 0.0;
  Image? _image;
  final List<Picture> _sourceBatches = [];

  AtlasTexture({
    int initialSize = defaultInitialSize,
    int maxSize = defaultMaxSize,
    this._budget,
  }) : assert(initialSize > 0, 'initialSize must be positive'),
       assert(maxSize >= initialSize, 'maxSize must be >= initialSize'),
       _initialSize = initialSize,
       _maxSize = maxSize {
    _width = initialSize;
    _height = initialSize;
  }

  Image? get image => _image;

  AtlasEntry? allocate({
    required double width,
    required double height,
    required double bearingY,
    double bearingX = 0.0,
    required AtlasEntryLane lane,
  }) {
    final plan = _plan(width, height);
    if (plan == null) return null;
    final bytes = plan.width * plan.height * 4;
    final budget = _budget;
    if (budget != null && !budget.resizeImage(_chargedBytes, bytes)) {
      return null;
    }
    _chargedBytes = bytes;
    _width = plan.width;
    _height = plan.height;
    _packX = plan.x;
    _packY = plan.y;
    _rowHeight = plan.rowHeight;
    _slabLeft = plan.slabLeft;

    final entry = AtlasEntry(
      srcLeft: _packX,
      srcTop: _packY,
      srcRight: _packX + width,
      srcBottom: _packY + height,
      bearingY: bearingY,
      bearingX: bearingX,
      lane: lane,
    );

    _packX += width + padding;
    _rowHeight = max(_rowHeight, height);
    return entry;
  }

  void clear() {
    _disposeSourceBatches();
    _image?.dispose();
    _image = null;
    _packX = 0;
    _packY = 0;
    _rowHeight = 0;
    _slabLeft = 0;
    _width = _initialSize;
    _height = _initialSize;
    _releaseBudget();
  }

  void dispose() {
    _disposeSourceBatches();
    _image?.dispose();
    _image = null;
    _releaseBudget();
  }

  void _releaseBudget() {
    final budget = _budget;
    if (budget != null) budget.releaseImage(_chargedBytes);
    _chargedBytes = 0;
  }

  void _disposeSourceBatches() {
    for (final batch in _sourceBatches) {
      batch.dispose();
    }
    _sourceBatches.clear();
  }

  void replaceImage(void Function(Canvas canvas) paintPending) {
    final batchRecorder = PictureRecorder();
    late final Picture batch;
    try {
      paintPending(Canvas(batchRecorder));
      batch = batchRecorder.endRecording();
    } finally {
      if (batchRecorder.isRecording) batchRecorder.endRecording().dispose();
    }

    final publicationRecorder = PictureRecorder();
    Picture? publication;
    var committed = false;
    try {
      final canvas = Canvas(publicationRecorder);
      for (final source in _sourceBatches) {
        canvas.drawPicture(source);
      }
      canvas.drawPicture(batch);
      publication = publicationRecorder.endRecording();
      final nextImage = publication.toImageSync(_width, _height);
      final previousImage = _image;
      _sourceBatches.add(batch);
      _image = nextImage;
      committed = true;
      previousImage?.dispose();
    } finally {
      if (publicationRecorder.isRecording) {
        publicationRecorder.endRecording().dispose();
      }
      publication?.dispose();
      if (!committed) batch.dispose();
    }
  }

  ({
    int width,
    int height,
    double x,
    double y,
    double rowHeight,
    double slabLeft,
  })?
  _plan(double glyphWidth, double glyphHeight) {
    if (glyphWidth + padding > _maxSize || glyphHeight + padding > _maxSize) {
      return null;
    }
    var width = _width;
    var height = _height;
    var x = _packX;
    var y = _packY;
    var rowHeight = _rowHeight;
    var slabLeft = _slabLeft;
    while (slabLeft + glyphWidth + padding > width) {
      if (width == _maxSize) return null;
      width = min(width * 2, _maxSize);
    }
    while (glyphHeight + padding > height) {
      if (height == _maxSize) return null;
      height = min(height * 2, _maxSize);
    }
    if (x + glyphWidth + padding > width) {
      x = slabLeft;
      y += rowHeight + padding;
      rowHeight = 0;
    }
    while (y + glyphHeight + padding > height) {
      if (height < _maxSize) {
        height = min(height * 2, _maxSize);
      } else {
        if (width == _maxSize) return null;
        slabLeft = width + padding;
        width = min(width * 2, _maxSize);
        while (slabLeft + glyphWidth + padding > width) {
          if (width == _maxSize) return null;
          width = min(width * 2, _maxSize);
        }
        x = slabLeft;
        y = 0;
        rowHeight = 0;
      }
    }
    return (
      width: width,
      height: height,
      x: x,
      y: y,
      rowHeight: rowHeight,
      slabLeft: slabLeft,
    );
  }
}

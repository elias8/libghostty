import 'dart:ui';

import '../atlas_entry.dart';

abstract class GlyphRaster {
  final Size extent;
  final Offset bearing;
  final double gutter;

  GlyphRaster(this.extent, {this.bearing = Offset.zero, this.gutter = 0});

  void paintSource(Canvas canvas);

  void dispose() {}

  DirectGlyph record(AtlasEntryLane lane) {
    final recorder = PictureRecorder();
    try {
      final canvas = Canvas(recorder);
      canvas.clipRect(Offset.zero & extent, doAntiAlias: false);
      paintSource(canvas);
      return DirectGlyph(
        recorder.endRecording(),
        extent,
        lane,
        bearing.dx,
        bearing.dy,
      );
    } finally {
      if (recorder.isRecording) recorder.endRecording().dispose();
      dispose();
    }
  }
}

final class ParagraphRaster extends GlyphRaster {
  final Paragraph paragraph;
  final Offset paragraphOffset;
  final double scaleX;
  final double scaleY;

  ParagraphRaster(
    this.paragraph,
    super.extent, {
    super.bearing,
    required this.paragraphOffset,
    this.scaleX = 1,
    this.scaleY = 1,
  });

  @override
  void paintSource(Canvas canvas) {
    canvas.save();
    canvas.clipRect(Offset.zero & extent);
    canvas.translate(paragraphOffset.dx, paragraphOffset.dy);
    canvas.scale(scaleX, scaleY);
    canvas.drawParagraph(paragraph, Offset.zero);
    canvas.restore();
  }

  @override
  void dispose() => paragraph.dispose();
}

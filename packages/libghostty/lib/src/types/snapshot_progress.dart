import 'package:meta/meta.dart';

import '../generated/libghostty_enums.g.dart';

/// Result of restoring one terminal snapshot record.
@immutable
sealed class SnapshotProgress {
  /// Screen affected by this record.
  final TerminalScreen screen;

  const SnapshotProgress({required this.screen});
}

/// Result of restoring a history page.
final class SnapshotPageProgress extends SnapshotProgress {
  /// Rows prepended from the page. Zero means the page could not be applied.
  final int rows;

  /// Page records remaining in this screen's history sequence.
  final int remaining;

  const SnapshotPageProgress({
    required super.screen,
    required this.rows,
    required this.remaining,
  });

  @override
  int get hashCode => Object.hash(screen, rows, remaining);

  @override
  bool operator ==(Object other) =>
      other is SnapshotPageProgress &&
      other.screen == screen &&
      other.rows == rows &&
      other.remaining == remaining;
}

/// Result of restoring pixels for a Kitty image or animation frame.
final class SnapshotImageProgress extends SnapshotProgress {
  /// Kitty image identifier.
  final int imageId;

  /// Kitty frame number. One is the image itself; later numbers are frames.
  final int frame;

  /// Bytes attached to the image. Zero means the pixels were dropped.
  final int bytes;

  const SnapshotImageProgress({
    required super.screen,
    required this.imageId,
    required this.frame,
    required this.bytes,
  });

  @override
  int get hashCode => Object.hash(screen, imageId, frame, bytes);

  @override
  bool operator ==(Object other) =>
      other is SnapshotImageProgress &&
      other.screen == screen &&
      other.imageId == imageId &&
      other.frame == frame &&
      other.bytes == bytes;
}

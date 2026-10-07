import 'dart:typed_data';

import '../../generated/libghostty_enums.g.dart';
import '../types.dart';

abstract interface class SnapshotBindings {
  LibGhosttyHandle snapshotDecoderDecode(LibGhosttyHandle decoder);
  void snapshotDecoderFree(LibGhosttyHandle decoder);
  int? snapshotDecoderHistoryRows(
    LibGhosttyHandle decoder,
    TerminalScreen screen,
  );
  LibGhosttyHandle snapshotDecoderNew(
    Uint8List bytes, {
    int? maxContinuationBytes,
    bool retainContinuation = false,
    bool compressHistory = false,
  });
  RawSnapshotProgress? snapshotDecoderNext(LibGhosttyHandle decoder);
  LibGhosttyHandle snapshotDecoderReady(LibGhosttyHandle decoder);
  bool snapshotDecoderRetainContinuation(LibGhosttyHandle decoder);
  bool snapshotDecoderCompressHistory(LibGhosttyHandle decoder);
  int snapshotDecoderSourceOffset(LibGhosttyHandle decoder);
  Uint8List snapshotEncode(LibGhosttyHandle terminal);
}

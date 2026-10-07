import '../../generated/libghostty_enums.g.dart';
import '../../types/types.dart';
import '../types.dart';

abstract interface class ParserBindings {
  OscCommandType oscCommandType(LibGhosttyHandle command);
  String? oscCommandWindowTitle(LibGhosttyHandle command);
  RawOscUnknownCommandData? oscCommandUnknownData(LibGhosttyHandle command);
  LibGhosttyHandle oscEnd(LibGhosttyHandle parser, int terminator);
  void oscFeedByte(LibGhosttyHandle parser, int byte);
  void oscFree(LibGhosttyHandle parser);
  LibGhosttyHandle oscNew({required int unknownMaxBytes});
  void oscReset(LibGhosttyHandle parser);

  void sgrFree(LibGhosttyHandle parser);
  LibGhosttyHandle sgrNew();
  SgrAttribute? sgrNext(LibGhosttyHandle parser);
  void sgrReset(LibGhosttyHandle parser);
  void sgrSetParams(
    LibGhosttyHandle parser,
    List<int> params,
    List<String>? separators,
  );
}

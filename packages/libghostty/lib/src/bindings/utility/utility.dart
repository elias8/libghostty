import 'dart:typed_data';

import '../../generated/libghostty_enums.g.dart';
import '../../types/types.dart';

abstract interface class UtilityBindings {
  String version();
  int buildInfo(BuildInfo data);
  bool buildInfoBool(BuildInfo data);
  String buildInfoString(BuildInfo data);

  double colorContrast(RgbColor a, RgbColor b);
  double colorLuminance(RgbColor color);
  List<RgbColor> colorPaletteDefault();
  List<RgbColor> colorPaletteGenerate({
    List<RgbColor>? base,
    Set<int> skip = const {},
    required RgbColor background,
    required RgbColor foreground,
    required bool harmonious,
  });
  RgbColor colorParse(String value);
  ({int index, RgbColor color}) colorParsePaletteEntry(String value);
  RgbColor colorParseX11(String name);
  double colorPerceivedLuminance(RgbColor color);

  String colorSchemeReportEncode(ColorScheme scheme);
  List<X11ColorName> colorX11Names();
  String focusEncode(FocusEvent event);
  String modeReportEncode(int mode, ModeReportState state);

  Uint8List pasteEncode(String data, {required bool bracketed});
  bool pasteIsSafe(String data);

  String sizeReportEncode(
    SizeReportStyle style,
    int rows,
    int columns,
    int cellWidth,
    int cellHeight,
  );
  Style styleDefault();
  bool styleIsDefault(Style style);

  int unicodeCodepointWidth(int codepoint);
  ({int consumed, int width}) unicodeGraphemeWidth(List<int> codepoints);
}

int styleFlags(Style style) =>
    (style.bold ? 1 << 0 : 0) |
    (style.italic ? 1 << 1 : 0) |
    (style.faint ? 1 << 2 : 0) |
    (style.blink ? 1 << 3 : 0) |
    (style.inverse ? 1 << 4 : 0) |
    (style.invisible ? 1 << 5 : 0) |
    (style.strikethrough ? 1 << 6 : 0) |
    (style.overline ? 1 << 7 : 0) |
    (style.underline.value << 8);

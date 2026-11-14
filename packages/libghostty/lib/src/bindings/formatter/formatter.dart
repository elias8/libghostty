import '../../generated/libghostty_enums.g.dart';
import '../../types/types.dart';
import '../types.dart';

abstract interface class FormatterBindings {
  String formatterFormat(LibGhosttyHandle formatter);

  void formatterFree(LibGhosttyHandle formatter);

  /// The selection must be refreshed or cleared after any terminal mutation.
  void formatterSetSelection(
    LibGhosttyHandle formatter,
    RawSelection? selection,
  );

  /// A supplied selection is valid only until the next terminal mutation.
  LibGhosttyHandle formatterTerminalNew(
    LibGhosttyHandle terminal,
    FormatterFormat format, {
    bool unwrap = false,
    bool trim = false,
    FormatterExtra extra = const FormatterExtra(),
    RawSelection? selection,
  });
}

int formatterExtrasMask(FormatterExtra extra) {
  final flags = [
    extra.palette,
    extra.modes,
    extra.scrollingRegion,
    extra.tabstops,
    extra.pwd,
    extra.keyboard,
    extra.cursor,
    extra.style,
    extra.hyperlink,
    extra.protection,
    extra.kittyKeyboard,
    extra.charsets,
  ];
  var mask = 0;
  for (var i = 0; i < flags.length; i++) {
    if (flags[i]) mask |= 1 << i;
  }
  return mask;
}

/// Terminal emulation powered by libghostty.
///
/// ```dart
/// import 'package:libghostty/libghostty.dart';
/// ```
library;

export 'src/bindings/bindings.dart' show initializeForWeb;
export 'src/color.dart';
export 'src/enums/key.dart';
export 'src/enums/key_action.dart';
export 'src/enums/kitty_key_flags.dart';
export 'src/enums/mods.dart';
export 'src/enums/option_as_alt.dart';
export 'src/enums/underline_style.dart';
export 'src/exceptions.dart' hide checkResult, throwResult;
export 'src/key_encoder.dart';
export 'src/key_event.dart';
export 'src/paste.dart';
export 'src/terminal/cell.dart' show Cell, CellStyle;
export 'src/terminal/cursor.dart' show Cursor, CursorShape;
export 'src/terminal/line.dart' show Line;
export 'src/terminal/modes.dart' show TerminalModes;
export 'src/terminal/screen.dart' show Screen;
export 'src/terminal/scrollback.dart' show Scrollback;
export 'src/terminal/terminal.dart';
export 'src/terminal/terminal_viewport.dart';

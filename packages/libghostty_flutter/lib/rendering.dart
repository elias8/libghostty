/// Terminal rendering layer.
///
/// Provides [TerminalRenderer], a Flutter widget that paints a terminal
/// screen with cell backgrounds, styled text, cursors, and selection
/// overlays. Also exports [TerminalSelection] for specifying selected
/// cell ranges.
library;

export 'src/rendering/selection.dart';
export 'src/rendering/terminal_renderer.dart' show TerminalRenderer;

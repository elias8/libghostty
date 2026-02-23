import 'package:libghostty/libghostty.dart';

class TerminalDump {
  static List<String> allContent(Terminal terminal) {
    return [...scrollbackContent(terminal), ...screenContent(terminal)];
  }

  static bool hasContentOverlap(Terminal terminal) {
    final scrollback = scrollbackContent(
      terminal,
    ).map((l) => l.trimRight()).where((l) => l.isNotEmpty).toSet();
    final screen = screenContent(
      terminal,
    ).map((l) => l.trimRight()).where((l) => l.isNotEmpty).toSet();
    return scrollback.intersection(screen).isNotEmpty;
  }

  static List<String> nonEmptyContent(Terminal terminal) {
    return allContent(
      terminal,
    ).map((line) => line.trimRight()).where((line) => line.isNotEmpty).toList();
  }

  static List<String> screenContent(Terminal terminal) {
    final lines = <String>[];
    for (var row = 0; row < terminal.screen.rows; row++) {
      lines.add(terminal.screen.lineAt(row).text);
    }
    return lines;
  }

  static List<String> scrollbackContent(Terminal terminal) {
    final lines = <String>[];
    for (var i = 0; i < terminal.scrollback.length; i++) {
      lines.add(terminal.scrollback.lineAt(i).text);
    }
    return lines;
  }

  static List<String> viewportContent(
    Terminal terminal, {
    int scrollOffset = 0,
  }) {
    final viewport = TerminalViewport(
      screen: terminal.screen,
      scrollback: terminal.scrollback,
      scrollOffset: scrollOffset,
    );
    final lines = <String>[];
    for (var row = 0; row < viewport.rows; row++) {
      lines.add(viewport.lineAt(row).text);
    }
    return lines;
  }
}

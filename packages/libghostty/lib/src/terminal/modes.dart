import 'package:meta/meta.dart';

/// Terminal mode flags set by DECSET/DECRST and SM/RM sequences.
@immutable
class TerminalModes {
  /// Marks pasted text so apps can tell it apart from keystrokes (DECSET 2004).
  final bool bracketedPaste;

  /// Separate screen buffer for full-screen apps like vim.
  final bool alternateScreen;

  /// Arrow keys emit app-mode sequences instead of ANSI cursors (DECSET 1).
  final bool cursorKeyApplication;

  /// Numpad emits app-mode sequences instead of digits (DECSET 66).
  final bool keypadApplication;

  /// Text wraps at the right margin; when off, overwrites the last
  /// column (DECSET 7).
  final bool autoWrap;

  /// Cursor addressing is relative to the scroll region (DECSET 6).
  final bool originMode;

  /// Characters insert and shift text right instead of overwriting (SM 4).
  final bool insertMode;

  const TerminalModes({
    this.bracketedPaste = false,
    this.alternateScreen = false,
    this.cursorKeyApplication = false,
    this.keypadApplication = false,
    this.autoWrap = true,
    this.originMode = false,
    this.insertMode = false,
  });

  @override
  int get hashCode => Object.hash(
    bracketedPaste,
    alternateScreen,
    cursorKeyApplication,
    keypadApplication,
    autoWrap,
    originMode,
    insertMode,
  );

  @override
  bool operator ==(Object other) =>
      other is TerminalModes &&
      other.bracketedPaste == bracketedPaste &&
      other.alternateScreen == alternateScreen &&
      other.cursorKeyApplication == cursorKeyApplication &&
      other.keypadApplication == keypadApplication &&
      other.autoWrap == autoWrap &&
      other.originMode == originMode &&
      other.insertMode == insertMode;

  TerminalModes copyWith({
    bool? bracketedPaste,
    bool? alternateScreen,
    bool? cursorKeyApplication,
    bool? keypadApplication,
    bool? autoWrap,
    bool? originMode,
    bool? insertMode,
  }) {
    return TerminalModes(
      bracketedPaste: bracketedPaste ?? this.bracketedPaste,
      alternateScreen: alternateScreen ?? this.alternateScreen,
      cursorKeyApplication: cursorKeyApplication ?? this.cursorKeyApplication,
      keypadApplication: keypadApplication ?? this.keypadApplication,
      autoWrap: autoWrap ?? this.autoWrap,
      originMode: originMode ?? this.originMode,
      insertMode: insertMode ?? this.insertMode,
    );
  }

  @override
  String toString() {
    final flags = <String>[];
    if (bracketedPaste) flags.add('bracketedPaste');
    if (alternateScreen) flags.add('alternateScreen');
    if (cursorKeyApplication) flags.add('cursorKeyApplication');
    if (keypadApplication) flags.add('keypadApplication');
    if (autoWrap) flags.add('autoWrap');
    if (originMode) flags.add('originMode');
    if (insertMode) flags.add('insertMode');
    return 'TerminalModes(${flags.join(', ')})';
  }
}

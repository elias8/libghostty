import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/services.dart' show KeyEvent;
import 'package:libghostty/libghostty.dart' show Key, KeyAction, Mods;

/// A keyboard event normalized for terminal protocol encoding.
///
/// Unlike Flutter's [KeyEvent], this includes the active layout's unshifted
/// codepoint and the modifiers consumed while producing [text].
@immutable
final class TerminalKeyboardEvent {
  /// The physical, layout-independent key.
  final Key key;

  /// Whether the key was pressed, repeated, or released.
  final KeyAction action;

  /// Modifier and lock state at the time of the event.
  final Mods mods;

  /// Modifiers used by the active layout to produce [text].
  final Mods consumedMods;

  /// Text produced by the active keyboard layout, if any.
  final String? text;

  /// The active layout's Unicode codepoint for this key without modifiers.
  ///
  /// Zero means that the platform could not provide a single codepoint.
  final int unshiftedCodepoint;

  /// Whether the event belongs to an active dead-key or IME composition.
  final bool composing;

  /// Whether platform text input should handle this event instead of the
  /// terminal key encoder.
  final bool deferToTextInput;

  const TerminalKeyboardEvent({
    required this.key,
    required this.action,
    required this.mods,
    this.consumedMods = const Mods.none(),
    this.text,
    this.unshiftedCodepoint = 0,
    this.composing = false,
    this.deferToTextInput = false,
  }) : assert(
         unshiftedCodepoint >= 0 &&
             unshiftedCodepoint <= 0x10FFFF &&
             (unshiftedCodepoint < 0xD800 || unshiftedCodepoint > 0xDFFF),
         'unshiftedCodepoint must be a valid Unicode scalar or zero',
       );

  /// Returns a copy with selected fields replaced.
  TerminalKeyboardEvent copyWith({
    Key? key,
    KeyAction? action,
    Mods? mods,
    Mods? consumedMods,
    String? text,
    bool clearText = false,
    int? unshiftedCodepoint,
    bool? composing,
    bool? deferToTextInput,
  }) {
    return TerminalKeyboardEvent(
      key: key ?? this.key,
      action: action ?? this.action,
      mods: mods ?? this.mods,
      consumedMods: consumedMods ?? this.consumedMods,
      text: clearText ? null : text ?? this.text,
      unshiftedCodepoint: unshiftedCodepoint ?? this.unshiftedCodepoint,
      composing: composing ?? this.composing,
      deferToTextInput: deferToTextInput ?? this.deferToTextInput,
    );
  }
}

/// Overrides or enriches flterm's normalized keyboard event.
///
/// [fallback] contains all information available from Flutter and flterm's
/// native desktop companion. Custom runners can replace fields with metadata
/// captured before Flutter normalizes the platform key event.
typedef TerminalKeyEventNormalizer =
    TerminalKeyboardEvent Function(
      KeyEvent event,
      TerminalKeyboardEvent fallback,
    );

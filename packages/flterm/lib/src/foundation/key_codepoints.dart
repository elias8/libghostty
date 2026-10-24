import 'package:libghostty/libghostty.dart' show Key;

final Map<int, Key> _codepointToKey = {
  0x20: Key.space,
  0x21: Key.digit1,
  0x22: Key.quote,
  0x23: Key.digit3,
  0x24: Key.digit4,
  0x25: Key.digit5,
  0x26: Key.digit7,
  0x27: Key.quote,
  0x28: Key.digit9,
  0x29: Key.digit0,
  0x2a: Key.digit8,
  0x2b: Key.equal,
  0x2c: Key.comma,
  0x2d: Key.minus,
  0x2e: Key.period,
  0x2f: Key.slash,
  for (var i = 0; i < 26; i++) 0x61 + i: Key.values[Key.a.index + i],
  for (var i = 0; i < 26; i++) 0x41 + i: Key.values[Key.a.index + i],
  for (var i = 0; i < 10; i++) 0x30 + i: Key.values[Key.digit0.index + i],
  0x3a: Key.semicolon,
  0x3b: Key.semicolon,
  0x3c: Key.comma,
  0x3d: Key.equal,
  0x3e: Key.period,
  0x3f: Key.slash,
  0x40: Key.digit2,
  0x5b: Key.bracketLeft,
  0x5c: Key.backslash,
  0x5d: Key.bracketRight,
  0x5e: Key.digit6,
  0x5f: Key.minus,
  0x60: Key.backquote,
  0x7b: Key.bracketLeft,
  0x7c: Key.backslash,
  0x7d: Key.bracketRight,
  0x7e: Key.backquote,
};

final Map<Key, int> _keyToCodepoint = {
  Key.backquote: 0x60,
  Key.backslash: 0x5c,
  Key.bracketLeft: 0x5b,
  Key.bracketRight: 0x5d,
  Key.comma: 0x2c,
  for (var i = 0; i < 26; i++) Key.values[Key.a.index + i]: 0x61 + i,
  for (var i = 0; i < 10; i++) Key.values[Key.digit0.index + i]: 0x30 + i,
  Key.equal: 0x3d,
  Key.minus: 0x2d,
  Key.period: 0x2e,
  Key.quote: 0x27,
  Key.semicolon: 0x3b,
  Key.slash: 0x2f,
  Key.space: 0x20,
};

/// Maps a Unicode [codepoint] to the corresponding libghostty [Key].
///
/// Covers ASCII letters, digits, space, and US-layout punctuation. Shifted
/// characters map to the same physical key as their unshifted pair.
Key? keyFromCodepoint(int codepoint) => _codepointToKey[codepoint];

/// Returns the lowercase ASCII codepoint for [key], or 0 for non-character
/// keys. Punctuation keys report their US-layout unshifted codepoint.
///
/// Used by the key encoder to determine the unshifted codepoint that
/// libghostty expects for keyboard input encoding.
int unshiftedCodepointForKey(Key key) => _keyToCodepoint[key] ?? 0;

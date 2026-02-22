/// Underline rendering style for terminal text.
///
/// Set via SGR escape sequences.
///
/// ```dart
/// final style = UnderlineStyle.fromNative(cell.underlineStyle);
/// if (style == UnderlineStyle.curly) {
///   print('curly underline');
/// }
/// ```
// Maps 1:1 with the native GhosttySgrUnderline enum.
enum UnderlineStyle {
  none,
  single,
  doubleLine,
  curly,
  dotted,
  dashed;

  static UnderlineStyle fromNative(int value) {
    if (value >= 0 && value < UnderlineStyle.values.length) {
      return UnderlineStyle.values[value];
    }
    return UnderlineStyle.none;
  }
}

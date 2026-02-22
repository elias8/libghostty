/// macOS option key behavior for terminal input.
///
/// Controls whether the macOS Option key is treated as Alt for keyboard
/// input encoding.
///
/// ```dart
/// encoder.setOptionAsAlt(OptionAsAlt.left);
/// ```
// Maps 1:1 with the native GhosttyOptionAsAlt enum.
enum OptionAsAlt {
  none,
  both,
  left,
  right;

  int get nativeValue => index;
}

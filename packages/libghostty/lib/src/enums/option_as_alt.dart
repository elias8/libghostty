/// macOS Option key behavior for terminal input.
///
/// Controls whether the macOS Option key is treated as Alt for keyboard
/// input encoding. On macOS, the Option key normally produces special
/// characters (e.g., Option+A → å). Setting this to a non-[none] value
/// makes the Option key behave as Alt instead, sending escape sequences
/// that terminal applications expect.
///
/// ```dart
/// encoder.setOptionAsAlt(OptionAsAlt.left);
/// ```
// Maps 1:1 with the native GhosttyOptionAsAlt enum.
enum OptionAsAlt {
  /// Option key produces macOS special characters (default behavior).
  none(0),

  /// Both Option keys are treated as Alt.
  both(1),

  /// Only the left Option key is treated as Alt.
  left(2),

  /// Only the right Option key is treated as Alt.
  right(3);

  final int nativeValue;

  const OptionAsAlt(this.nativeValue);
}

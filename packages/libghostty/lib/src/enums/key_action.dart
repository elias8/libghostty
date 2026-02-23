/// The action type for a keyboard input event.
///
/// Represents the state transition of a physical key.
///
/// ```dart
/// final action = KeyAction.fromNative(event.action);
/// if (action == KeyAction.press) {
///   print('key pressed');
/// }
/// ```
// Maps 1:1 with the native GhosttyKeyAction enum.
enum KeyAction {
  release(0),
  press(1),
  repeat(2);

  final int nativeValue;

  const KeyAction(this.nativeValue);

  static KeyAction fromNative(int value) {
    return KeyAction.values.firstWhere(
      (e) => e.nativeValue == value,
      orElse: () => KeyAction.press,
    );
  }
}

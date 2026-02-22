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
  release,
  press,
  repeat;

  int get nativeValue => index;

  static KeyAction fromNative(int value) {
    return KeyAction.values[value];
  }
}

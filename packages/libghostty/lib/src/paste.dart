import 'bindings/bindings.dart';

/// Returns `true` if [data] is safe to paste into a terminal.
///
/// Data is considered unsafe if it contains newlines or the bracketed
/// paste end sequence (`\x1b[201~`).
///
/// ```dart
/// pasteIsSafe('hello world');        // true
/// pasteIsSafe('rm -rf /\n');         // false
/// pasteIsSafe('\x1b[201~injected');  // false
/// ```
bool pasteIsSafe(String data) => bindings.pasteIsSafe(data);

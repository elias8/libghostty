/// Base exception for all errors originating from libghostty.
///
/// ```dart
/// try {
///   terminal.write(input);
/// } on LibGhosttyException catch (e) {
///   switch (e) {
///     case OutOfMemoryException():
///       print('allocation failed');
///     case InvalidValueException():
///       print('bad parameter: ${e.message}');
///     case DisposedException():
///       print('resource already disposed');
///   }
/// }
/// ```
// Maps to native GhosttyResult error codes from the C API.
sealed class LibGhosttyException implements Exception {
  final String message;

  const LibGhosttyException(this.message);

  @override
  String toString() => message;
}

/// A memory allocation failed.
///
/// ```dart
/// try {
///   final terminal = Terminal(cols: 80, rows: 24);
/// } on OutOfMemoryException {
///   print('allocation failed');
/// }
/// ```
// Corresponds to GHOSTTY_OUT_OF_MEMORY (-1).
class OutOfMemoryException extends LibGhosttyException {
  const OutOfMemoryException([super.message = 'Memory allocation failed.']);
}

/// An invalid parameter was passed to the API.
///
/// ```dart
/// try {
///   terminal.resize(cols: -1, rows: 24);
/// } on InvalidValueException {
///   print('invalid parameter');
/// }
/// ```
// Corresponds to GHOSTTY_INVALID_VALUE (-2).
class InvalidValueException extends LibGhosttyException {
  const InvalidValueException([super.message = 'Invalid value provided.']);
}

/// A method was called on a resource that has already been disposed.
///
/// ```dart
/// final terminal = Terminal(cols: 80, rows: 24);
/// terminal.dispose();
/// try {
///   terminal.write('hello');
/// } on DisposedException {
///   print('terminal is disposed');
/// }
/// ```
class DisposedException extends LibGhosttyException {
  const DisposedException(String typeName)
    : super('$typeName has already been disposed.');
}

Never throwResult(int result) {
  switch (result) {
    case _outOfMemory:
      throw const OutOfMemoryException();
    case _invalidValue:
      throw const InvalidValueException();
    default:
      throw StateError('Unknown error code: $result');
  }
}

void checkResult(int result) {
  if (result != _success) {
    throwResult(result);
  }
}

const _success = 0;
const _outOfMemory = -1;
const _invalidValue = -2;

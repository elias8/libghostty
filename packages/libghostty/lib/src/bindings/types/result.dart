import '../../ffi/libghostty_enums.g.dart';

/// Unwraps a [CResult], returning the value on success or throwing via
/// [checkCode].
T check<T>(CResult<T> result) {
  checkCode(result.$1);
  return result.$2;
}

/// Throws if [code] is a non-success [Result].
///
/// Throws [OutOfMemoryException] for [Result.outOfMemory],
/// [InvalidValueException] for [Result.invalidValue],
/// [OutOfSpaceException] for [Result.outOfSpace], and
/// [NoValueException] for [Result.noValue], [IoException] for
/// [Result.ioError], and [LimitExceededException] for
/// [Result.limitExceeded].
void checkCode(Result code) {
  switch (code) {
    case Result.outOfMemory:
      throw const OutOfMemoryException();
    case Result.invalidValue:
      throw const InvalidValueException();
    case Result.outOfSpace:
      throw const OutOfSpaceException();
    case Result.noValue:
      throw const NoValueException();
    case Result.ioError:
      throw const IoException();
    case Result.limitExceeded:
      throw const LimitExceededException();
    case Result.success:
      break;
  }
}

/// A C function result: the [Result] code paired with a value.
///
/// The value may be invalid when the code is non-success. Use [check] to
/// unwrap the value or [checkCode] to validate the code alone.
typedef CResult<T> = (Result code, T value);

/// An invalid parameter was passed to the native API.
class InvalidValueException extends LibGhosttyException {
  const InvalidValueException([super.message = 'Invalid value provided.']);
}

/// Base exception for all errors originating from libghostty.
sealed class LibGhosttyException implements Exception {
  final String message;

  const LibGhosttyException(this.message);

  @override
  String toString() => message;
}

/// The requested data has no value (e.g. an optional field that is unset).
///
/// Callers should handle [Result.noValue] before calling [check] or
/// [checkCode]. This should never occur in user code. If thrown, it
/// indicates a bug in the libghostty binding layer.
class NoValueException extends LibGhosttyException {
  const NoValueException([super.message = 'Requested value is not set.']);
}

/// A native memory allocation failed.
class OutOfMemoryException extends LibGhosttyException {
  const OutOfMemoryException([super.message = 'Memory allocation failed.']);
}

/// The provided output buffer was too small.
///
/// The retry logic inside the binding should handle [Result.outOfSpace]
/// internally. This should never occur in user code. If thrown, it
/// indicates a bug in the libghostty binding layer.
class OutOfSpaceException extends LibGhosttyException {
  const OutOfSpaceException([super.message = 'Output buffer too small.']);
}

/// An external I/O operation required by the native API failed.
class IoException extends LibGhosttyException {
  const IoException([super.message = 'An external I/O operation failed.']);
}

/// A configured output limit prevented the native operation from completing.
class LimitExceededException extends LibGhosttyException {
  const LimitExceededException([
    super.message = 'An operation exceeded a configured limit.',
  ]);
}

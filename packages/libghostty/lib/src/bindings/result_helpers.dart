import '../generated/libghostty_enums.g.dart';
import '../types/exceptions.dart';

/// Checks a raw libghostty result code without allocating on success.
@pragma('vm:prefer-inline')
void checkResultCode(int code, {String? operation}) {
  switch (code) {
    case 0:
      return;
    case -1:
      throw OutOfMemoryException(operation: operation);
    case -2:
      throw InvalidValueException(operation: operation);
    case -3:
      throw OutOfSpaceException(operation: operation);
    case -4:
      throw NoValueException(operation: operation);
    case -5:
      throw IoException(operation: operation);
    case -6:
      throw LimitExceededException(operation: operation);
    case -7:
      throw RejectedException(operation: operation);
    case -8:
      throw UnsupportedException(operation: operation);
    default:
      throw UnknownResultException(code, operation: operation);
  }
}

/// Checks a required-value operation and returns whether its output is valid.
///
/// The caller must invoke this before reading the operation's output storage.
/// The boolean is always `true` when this method returns normally.
@pragma('vm:prefer-inline')
bool checkRequiredCode(int code, {String? operation}) {
  checkResultCode(code, operation: operation);
  return true;
}

/// Checks an optional-value operation and returns whether its output is valid.
///
/// The caller must invoke this before reading the operation's output storage.
/// A `GHOSTTY_NO_VALUE` result returns `false`; every other non-success result
/// throws.
@pragma('vm:prefer-inline')
bool checkOptionalCode(int code, {String? operation}) {
  if (code == Result.noValue.value) return false;
  checkResultCode(code, operation: operation);
  return true;
}

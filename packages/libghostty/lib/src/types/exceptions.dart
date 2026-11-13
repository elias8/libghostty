/// Base exception for all errors originating from libghostty.
///
/// [code] is the numeric libghostty result when one exists. [operation]
/// identifies the operation that returned it. The default [toString] remains
/// the human-readable message unless operation context is available.
sealed class LibGhosttyException implements Exception {
  final String message;
  final int? code;
  final String? operation;
  final bool _showCode;

  const LibGhosttyException(
    this.message, {
    this.code,
    this.operation,
    bool showCode = false,
  }) : _showCode = showCode;

  @override
  String toString() {
    if (operation == null && !_showCode) return message;
    final context = <String>[
      if (operation != null) 'operation: $operation',
      if (code != null) 'code: $code',
    ].join(', ');
    return '$message ($context)';
  }
}

/// A required-value operation reported that no value was available.
///
/// Public APIs map expected absence to null. If this exception reaches user
/// code, the binding or linked libghostty artifact violated a required-value
/// contract. [operation] identifies that operation when available.
final class NoValueException extends LibGhosttyException {
  const NoValueException({
    String message = 'Requested value is not set.',
    String? operation,
  }) : super(message, code: -4, operation: operation);
}

/// A libghostty memory allocation failed.
final class OutOfMemoryException extends LibGhosttyException {
  const OutOfMemoryException({
    String message = 'Memory allocation failed.',
    String? operation,
  }) : super(message, code: -1, operation: operation);
}

/// Libghostty reported that an output buffer was too small after retrying.
///
/// The binding normally resizes output buffers internally. If this exception
/// reaches user code, the binding or linked artifact violated that retry
/// contract.
final class OutOfSpaceException extends LibGhosttyException {
  const OutOfSpaceException({
    String message = 'Output buffer too small.',
    String? operation,
  }) : super(message, code: -3, operation: operation);
}

/// Libghostty rejected a parameter or operation state as invalid.
///
/// [operation] identifies the rejected operation when that context is
/// available.
final class InvalidValueException extends LibGhosttyException {
  const InvalidValueException({
    String message = 'Invalid value provided.',
    String? operation,
  }) : super(message, code: -2, operation: operation);
}

/// An external I/O operation required by libghostty failed.
final class IoException extends LibGhosttyException {
  const IoException({
    String message = 'An external I/O operation failed.',
    String? operation,
  }) : super(message, code: -5, operation: operation);
}

/// A configured output limit prevented libghostty from completing an operation.
final class LimitExceededException extends LibGhosttyException {
  const LimitExceededException({
    String message = 'An operation exceeded a configured limit.',
    String? operation,
  }) : super(message, code: -6, operation: operation);
}

/// A safety check rejected an operation before it produced any output.
final class RejectedException extends LibGhosttyException {
  const RejectedException({super.operation})
    : super('The operation was rejected by a safety check.', code: -7);
}

/// The linked libghostty does not support the requested operation.
final class UnsupportedException extends LibGhosttyException {
  const UnsupportedException({super.operation})
    : super('The operation is not supported.', code: -8);
}

/// A result code not defined by the linked libghostty ABI.
///
/// [code] preserves the exact numeric value so callers can diagnose a newer
/// or target-specific ABI without losing information. [operation] identifies
/// the C operation that returned it when the binding supplies that context.
final class UnknownResultException extends LibGhosttyException {
  const UnknownResultException(int code, {super.operation})
    : super(
        'An unknown libghostty result code was returned.',
        code: code,
        showCode: true,
      );
}

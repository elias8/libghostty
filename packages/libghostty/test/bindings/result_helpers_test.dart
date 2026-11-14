import 'package:libghostty/src/bindings/result_helpers.dart';
import 'package:libghostty/src/generated/libghostty_enums.g.dart';
import 'package:libghostty/src/types/exceptions.dart';
import 'package:test/test.dart';

void main() {
  group('result translation', () {
    group('checkResultCode', () {
      test('accepts success', () {
        expect(() => checkResultCode(Result.success.value), returnsNormally);
      });

      test('maps out of memory', () {
        expect(
          () => checkResultCode(Result.outOfMemory.value),
          throwsA(isA<OutOfMemoryException>()),
        );
      });

      test('maps invalid value', () {
        expect(
          () => checkResultCode(Result.invalidValue.value),
          throwsA(isA<InvalidValueException>()),
        );
      });

      test('maps out of space', () {
        expect(
          () => checkResultCode(Result.outOfSpace.value),
          throwsA(isA<OutOfSpaceException>()),
        );
      });

      test('maps no value', () {
        expect(
          () => checkResultCode(Result.noValue.value),
          throwsA(isA<NoValueException>()),
        );
      });

      test('maps io error', () {
        expect(
          () => checkResultCode(Result.ioError.value),
          throwsA(isA<IoException>()),
        );
      });

      test('maps limit exceeded', () {
        expect(
          () => checkResultCode(Result.limitExceeded.value),
          throwsA(isA<LimitExceededException>()),
        );
      });

      test('maps unsupported with operation context', () {
        expect(
          () => checkResultCode(Result.unsupported.value, operation: 'test'),
          throwsA(
            isA<UnsupportedException>()
                .having((error) => error.code, 'code', -8)
                .having((error) => error.operation, 'operation', 'test'),
          ),
        );
      });

      test('retains known code and operation context', () {
        const error = InvalidValueException(operation: 'ghostty_terminal_set');

        expect(error.code, Result.invalidValue.value);
        expect(error.operation, 'ghostty_terminal_set');
        expect(
          error.toString(),
          'Invalid value provided. '
          '(operation: ghostty_terminal_set, code: -2)',
        );
      });

      test('preserves the legacy default exception string', () {
        expect(
          const InvalidValueException().toString(),
          'Invalid value provided.',
        );
      });

      test('retains an unknown positive code and operation', () {
        expect(
          () => checkResultCode(17, operation: 'ghostty_test'),
          throwsA(
            isA<UnknownResultException>()
                .having((error) => error.code, 'code', 17)
                .having(
                  (error) => error.operation,
                  'operation',
                  'ghostty_test',
                ),
          ),
        );
      });

      test('retains an unknown negative code and operation', () {
        expect(
          () => checkResultCode(-99, operation: 'ghostty_test'),
          throwsA(
            isA<UnknownResultException>()
                .having((error) => error.code, 'code', -99)
                .having(
                  (error) => error.operation,
                  'operation',
                  'ghostty_test',
                ),
          ),
        );
      });
    });

    group('required output', () {
      test('returns after successful status', () {
        expect(checkRequiredCode(Result.success.value), isTrue);
      });

      test('throws before a failed output is read', () {
        final output = _PoisonedOutput();

        expect(
          () => _readRequiredOutput(Result.invalidValue.value, output),
          throwsA(isA<InvalidValueException>()),
        );
      });

      test('throws no value for required output', () {
        expect(
          () => checkRequiredCode(Result.noValue.value),
          throwsA(isA<NoValueException>()),
        );
      });
    });

    group('optional output', () {
      test('returns false for no value', () {
        expect(checkOptionalCode(Result.noValue.value), isFalse);
      });

      test('throws for unsupported optional output', () {
        expect(
          () => checkOptionalCode(Result.unsupported.value),
          throwsA(isA<UnsupportedException>()),
        );
      });

      test('returns true after successful status', () {
        expect(checkOptionalCode(Result.success.value), isTrue);
      });

      test('throws before a failed output is read', () {
        final output = _PoisonedOutput();

        expect(
          () => _readOptionalOutput(Result.invalidValue.value, output),
          throwsA(isA<InvalidValueException>()),
        );
      });
    });
  });
}

Object _readRequiredOutput(int code, _PoisonedOutput output) {
  checkRequiredCode(code);
  return output.value;
}

Object? _readOptionalOutput(int code, _PoisonedOutput output) =>
    checkOptionalCode(code) ? output.value : null;

final class _PoisonedOutput {
  Object get value => throw StateError('poisoned output was read');
}

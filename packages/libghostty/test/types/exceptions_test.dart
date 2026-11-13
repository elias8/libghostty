import 'package:libghostty/src/types/exceptions.dart';
import 'package:test/test.dart';

void main() {
  group('LibGhosttyException', () {
    group('message', () {
      test('uses default messages', () {
        const outOfMemory = OutOfMemoryException();
        expect(outOfMemory.message, 'Memory allocation failed.');
        expect(outOfMemory.toString(), 'Memory allocation failed.');

        const invalidValue = InvalidValueException();
        expect(invalidValue.message, 'Invalid value provided.');
        expect(invalidValue.toString(), 'Invalid value provided.');

        const noValue = NoValueException();
        expect(noValue.message, 'Requested value is not set.');
        expect(noValue.toString(), 'Requested value is not set.');

        const outOfSpace = OutOfSpaceException();
        expect(outOfSpace.message, 'Output buffer too small.');
        expect(outOfSpace.toString(), 'Output buffer too small.');
      });

      test('uses custom messages', () {
        const outOfMemory = OutOfMemoryException(message: 'Custom OOM message');
        expect(outOfMemory.message, 'Custom OOM message');

        const invalidValue = InvalidValueException(message: 'Bad input');
        expect(invalidValue.message, 'Bad input');
      });
    });
  });
}

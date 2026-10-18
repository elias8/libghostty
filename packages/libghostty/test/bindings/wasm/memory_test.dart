@Tags(['wasm'])
library;

import 'dart:collection';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:libghostty/src/bindings/wasm/adapter.dart';
import 'package:libghostty/src/bindings/wasm/memory.dart';
import 'package:libghostty/src/generated/libghostty_wasm.g.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

@JS('String')
external JSString _stringify(JSAny value);

void main() {
  group('Memory', () {
    late web.Memory wasmMemory;
    late Memory memory;

    setUp(() {
      wasmMemory = web.Memory(web.MemoryDescriptor(initial: 1, maximum: 2));
      final exports = newJsObject()..['memory'] = wasmMemory;
      memory = Memory(GhosttyExports(exports));
    });

    test('reads exact u64 bits before and after memory growth', () {
      String decimal(int address) =>
          _stringify(memory.readU64BigInt(address)).toDart;
      memory.writeU32(16, 0xffffffff);
      memory.writeU32(20, 0xffffffff);
      expect(decimal(16), '18446744073709551615');
      wasmMemory.grow(1);
      memory.writeU32(65536, 0x0001f642);
      memory.writeU32(65540, 0x80000000);
      expect(decimal(65536), '9223372036854904386');
      expect(decimal(16), '18446744073709551615');
      expect(() => memory.readU64BigInt(131065), throwsStateError);
    });

    test('reuses typed views while the buffer is stable', () {
      final first = memory.view;

      final second = memory.view;

      expect(identical(second, first), isTrue);
      expect(memory.refreshCount, 1);
    });

    test('refreshes typed views after memory growth', () {
      final before = memory.view;
      wasmMemory.grow(1);

      final after = memory.view;

      expect(identical(after, before), isFalse);
      expect(memory.refreshCount, 2);
    });

    test('reads and writes through the refreshed buffer', () {
      memory.writeU32(0, 0x10203040);
      wasmMemory.grow(1);

      memory.writeU32(65536, 0x50607080);

      expect(memory.readU32(0), 0x10203040);
      expect(memory.readU32(65536), 0x50607080);
      expect(memory.refreshCount, 2);
    });

    for (final typed in [false, true]) {
      test('writes byte values at an offset typed=$typed', () {
        final values = <int>[-1, 256, 257];
        memory.writeBytes(3, typed ? Uint8List.fromList(values) : values);
        expect(memory.readBytes(2, 5), [0, 255, 0, 1, 0]);
      });

      test('accepts empty writes only within memory typed=$typed', () {
        final empty = typed ? Uint8List(0) : <int>[];
        memory.writeBytes(0, empty);
        memory.writeBytes(65536, empty);
        expect(() => memory.writeBytes(-1, empty), throwsStateError);
        expect(() => memory.writeBytes(65537, empty), throwsStateError);
      });
    }

    for (final destination in [1, 3]) {
      test('copies overlapping typed views to $destination', () {
        memory.writeBytes(0, Uint8List.fromList([0, 1, 2, 3, 4, 5, 6]));
        memory.writeBytes(destination, memory.readBytes(2, 3));
        expect(
          memory.readBytes(0, 7),
          destination == 1 ? [0, 2, 3, 4, 4, 5, 6] : [0, 1, 2, 2, 3, 4, 6],
        );
      });
    }

    test('preserves generic alias copy order', () {
      memory.writeBytes(0, const [0, 1, 2, 3, 4, 5]);
      final source = UnmodifiableListView<int>(memory.readBytes(2, 3));
      memory.writeBytes(1, source);
      expect(memory.readBytes(0, 6), [0, 2, 3, 4, 4, 5]);
    });

    test('writes bytes into a newly grown page', () {
      memory.writeBytes(16, Uint8List.fromList([1, 2, 3]));
      wasmMemory.grow(1);
      memory.writeBytes(65536, Uint8List.fromList([4, 5, 6]));
      expect(memory.readBytes(16, 3), [1, 2, 3]);
      expect(memory.readBytes(65536, 3), [4, 5, 6]);
      expect(memory.refreshCount, 2);
    });

    test('rejects a typed write before changing memory', () {
      memory.writeBytes(65534, const [7, 8]);
      expect(
        () => memory.writeBytes(65535, Uint8List.fromList([1, 2])),
        throwsStateError,
      );
      expect(memory.readBytes(65534, 2), [7, 8]);
    });

    test('reads a terminated C string', () {
      memory.writeBytes(16, const [0x6c, 0xc3, 0xb9, 0x00]);

      expect(memory.readCString(16), 'lù');
    });

    test('rejects an unterminated C string', () {
      memory.writeBytes(65535, const [0x6c]);

      expect(
        () => memory.readCString(65535),
        throwsA(
          predicate<Object>(
            (error) =>
                error is StateError &&
                error.toString().contains('Unterminated') &&
                error.toString().contains('65535'),
          ),
        ),
      );
    });

    test('rejects a C string address outside memory', () {
      expect(
        () => memory.readCString(65536),
        throwsA(
          predicate<Object>(
            (error) =>
                error is StateError &&
                error.toString().contains('Invalid') &&
                error.toString().contains('65536'),
          ),
        ),
      );
    });

    test('rejects an out-of-bounds byte read', () {
      expect(
        () => memory.readBytes(65535, 2),
        throwsA(
          predicate<Object>(
            (error) =>
                error is StateError &&
                error.toString().contains('address=65535') &&
                error.toString().contains('length=2'),
          ),
        ),
      );
    });

    test('rejects an out-of-bounds byte write', () {
      expect(
        () => memory.writeBytes(65535, const [1, 2]),
        throwsA(
          predicate<Object>(
            (error) =>
                error is StateError &&
                error.toString().contains('address=65535') &&
                error.toString().contains('length=2'),
          ),
        ),
      );
    });
  });
}

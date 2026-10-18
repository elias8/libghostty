@Tags(['ffi'])
library;

import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:libghostty/src/bindings/key/ffi.dart';
import 'package:libghostty/src/generated/libghostty_enums.g.dart';
import 'package:test/test.dart';

void main() {
  group('FfiKeyBindings', () {
    late FfiKeyBindings bindings;

    setUp(() {
      bindings = FfiKeyBindings();
    });

    test('creates and releases a key event', () {
      final event = bindings.keyEventNew();
      addTearDown(() => bindings.keyEventFree(event));

      expect(event.value, isNonZero);
    });

    test('round trips key event state', () {
      final event = bindings.keyEventNew();
      addTearDown(() => bindings.keyEventFree(event));

      bindings.keyEventSetAction(event, .press);
      bindings.keyEventSetKey(event, .c);
      bindings.keyEventSetMods(event, 4);
      bindings.keyEventSetConsumedMods(event, 2);
      bindings.keyEventSetComposing(event, composing: true);
      bindings.keyEventSetUnshiftedCodepoint(event, 0x63);

      expect(bindings.keyEventGetAction(event), KeyAction.press);
      expect(bindings.keyEventGetKey(event), Key.c);
      expect(bindings.keyEventGetMods(event), 4);
      expect(bindings.keyEventGetConsumedMods(event), 2);
      expect(bindings.keyEventGetComposing(event), isTrue);
      expect(bindings.keyEventGetUnshiftedCodepoint(event), 0x63);
    });

    group('keyEventSetUtf8', () {
      test(
        'clears native key text safely when replacement allocation fails',
        () {
          final allocator = _FailingTextAllocator();
          addTearDown(allocator.dispose);
          final bindings = FfiKeyBindings(textAllocator: allocator);
          final event = bindings.keyEventNew();
          final encoder = bindings.keyEncoderNew();
          var eventFreed = false;
          addTearDown(() {
            bindings.keyEncoderFree(encoder);
            if (!eventFreed) bindings.keyEventFree(event);
          });

          bindings.keyEventSetAction(event, .press);
          bindings.keyEventSetKey(event, .c);
          bindings.keyEventSetUtf8(event, 'c');
          final originalAddress = allocator.live.keys.single;

          expect(bindings.keyEventGetUtf8(event), 'c');
          expect(bindings.keyEncoderEncode(encoder, event), 'c');

          allocator.failNext = true;
          expect(
            () => bindings.keyEventSetUtf8(event, 'replacement'),
            throwsA(same(allocator.failure)),
          );
          expect(allocator.live.containsKey(originalAddress), isFalse);
          expect(allocator.releases, 1);

          expect(bindings.keyEventGetUtf8(event), isNull);
          expect(allocator.live, isEmpty);

          bindings.keyEventSetUtf8(event, 'é');

          expect(bindings.keyEventGetUtf8(event), 'é');
          expect(bindings.keyEncoderEncode(encoder, event), 'é');
          expect(allocator.allocations, 2);
          expect(allocator.releases, 1);
          expect(allocator.live.length, 1);
          expect(allocator.peakBytes, 2);

          bindings.keyEventSetUtf8(event, null);

          expect(bindings.keyEventGetUtf8(event), isNull);
          expect(allocator.live, isEmpty);
          expect(allocator.allocations, 2);
          expect(allocator.releases, 2);

          bindings.keyEventSetUtf8(event, 'abc');

          expect(bindings.keyEventGetUtf8(event), 'abc');

          bindings.keyEventSetUtf8(event, '');

          expect(bindings.keyEventGetUtf8(event), isNull);
          expect(allocator.live, isEmpty);
          expect(allocator.allocations, 3);
          expect(allocator.releases, 3);

          bindings.keyEventSetUtf8(event, 'z');

          expect(bindings.keyEventGetUtf8(event), 'z');
          expect(bindings.keyEncoderEncode(encoder, event), 'z');

          bindings.keyEventFree(event);
          eventFreed = true;

          expect(allocator.live, isEmpty);
          expect(allocator.allocations, 4);
          expect(allocator.releases, 4);
        },
      );
    });

    test('replaces retained UTF-8 text and releases it with the event', () {
      final event = bindings.keyEventNew();
      addTearDown(() => bindings.keyEventFree(event));

      bindings.keyEventSetUtf8(event, 'first');
      bindings.keyEventSetUtf8(event, 'second');
      bindings.keyEventSetUtf8(event, null);

      expect(bindings.keyEventGetUtf8(event), isNull);
    });

    test('encodes a key event and retries an out-of-space buffer', () {
      final event = bindings.keyEventNew();
      final encoder = bindings.keyEncoderNew();
      addTearDown(() {
        bindings.keyEncoderFree(encoder);
        bindings.keyEventFree(event);
      });

      bindings.keyEventSetAction(event, .press);
      bindings.keyEventSetKey(event, .c);
      final text = List.filled(256, 'c').join();
      bindings.keyEventSetUtf8(event, text);

      expect(bindings.keyEncoderEncode(encoder, event), text);
    });
  });
}

final class _FailingTextAllocator implements Allocator {
  final failure = StateError('forced text allocation failure');
  final live = <int, Pointer<NativeType>>{};
  var failNext = false;
  var allocations = 0;
  var releases = 0;
  final lengths = <int, int>{};
  var peakBytes = 0;

  @override
  Pointer<T> allocate<T extends NativeType>(int byteCount, {int? alignment}) {
    if (failNext) {
      failNext = false;
      throw failure;
    }
    final pointer = calloc.allocate<T>(byteCount, alignment: alignment);
    live[pointer.address] = pointer;
    lengths[pointer.address] = byteCount;
    final liveBytes = lengths.values.fold<int>(0, (a, b) => a + b);
    if (liveBytes > peakBytes) peakBytes = liveBytes;
    allocations++;
    return pointer;
  }

  @override
  void free(Pointer<NativeType> pointer) {
    expect(live.remove(pointer.address), isNotNull);
    lengths.remove(pointer.address);
    releases++;
    calloc.free(pointer);
  }

  void dispose() {
    final remaining = live.values.toList();
    for (final pointer in remaining) {
      free(pointer);
    }
  }
}

@Tags(['wasm'])
library;

import 'package:libghostty/src/bindings/wasm/scratch.dart';
import 'package:test/test.dart';

void main() {
  group('WasmScratchPool', () {
    test('release frees large storage but reuses small slots', () {
      final allocator = _TestScratchAllocator();
      final pool = WasmScratchPool(
        allocator,
        maxVariableLength: 1024,
        maxRetainedVariableLength: 16,
        maxRetainedVariableSlots: 2,
      );
      final first = pool.acquire(const []);
      final small = first.variableAddress(0, 8);
      final large = first.variableAddress(1, 128);
      final overflow = first.variableAddress(2, 8);
      first.release();
      expect(allocator.freedAddresses, [large, overflow]);
      expect(allocator.activeAllocations, {small});

      final second = pool.acquire(const []);
      expect(second.variableAddress(0, 8), small);
      expect(second.variableAddress(1, 8), isNot(large));
      second.release();
      pool.dispose();
      expect(allocator.activeAllocations, isEmpty);
    });

    test('reuses a frame after a zero-length overflow slot', () {
      final allocator = _TestScratchAllocator();
      final pool = WasmScratchPool(
        allocator,
        maxVariableLength: 64,
        maxRetainedVariableSlots: 1,
      );
      final first = pool.acquire(const []);
      expect(first.variable(2, 0, alignment: 8).alignment, 8);
      first.release();

      final second = pool.acquire(const []);
      expect(allocator.allocations, 0);
      final overflow = second.variableAddress(2, 8);
      second.release();
      expect(allocator.freedAddresses, [overflow]);
      expect(allocator.activeAllocations, isEmpty);
      pool.dispose();
    });

    test('release trims overflow slots after failed growth', () {
      final allocator = _TestScratchAllocator();
      final pool = WasmScratchPool(
        allocator,
        maxVariableLength: 64,
        maxRetainedVariableSlots: 1,
      );
      final first = pool.acquire(const []);
      final retained = first.variableAddress(0, 8);
      final overflow = first.variableAddress(2, 8, alignment: 8);
      allocator.failAllocation = true;
      expect(() => first.variable(2, 16, alignment: 8), throwsStateError);
      expect(first.variableAddress(2, 8, alignment: 8), overflow);
      first.release();
      expect(allocator.freedAddresses, [overflow]);

      allocator.failAllocation = false;
      final second = pool.acquire(const []);
      expect(second.variableAddress(0, 8), retained);
      expect(second.variable(2, 0).capacity, 0);
      expect(allocator.activeAllocations, {retained});
      second.release();
      pool.dispose();
    });

    test(
      'release frees capacity above the limit returned by the allocator',
      () {
        final allocator = _TestScratchAllocator()..extraCapacity = 16;
        final pool = WasmScratchPool(
          allocator,
          maxVariableLength: 64,
          maxRetainedVariableLength: 16,
        );
        final first = pool.acquire(const []);
        final region = first.variable(0, 8);
        expect(region.capacity, 24);
        expect(allocator.requests, [(length: 8, alignment: 1)]);
        first.release();
        expect(allocator.freedAddresses, [region.address]);
        expect(allocator.activeAllocations, isEmpty);

        final second = pool.acquire(const []);
        expect(second.variable(0, 0).capacity, 0);
        second.release();
        pool.dispose();
        expect(allocator.freeCalls, 1);
      },
    );

    void runWithFrame(WasmScratchFrame frame, void Function() operation) {
      try {
        operation();
      } finally {
        frame.release();
      }
    }

    void useWarmFrame(WasmScratchPool pool) {
      final frame = pool.acquire(const []);
      frame.variable(0, 8);
      frame.release();
    }

    test('reuses released fixed storage', () {
      final allocator = _TestScratchAllocator();
      final pool = WasmScratchPool(allocator, maxVariableLength: 64);
      const spec = ScratchSlotSpec(size: 12, alignment: 4);

      final first = pool.acquire([spec]);
      final firstAddress = first.fixed(0).address;
      first.release();

      final second = pool.acquire([spec]);

      expect(second.fixed(0).address, firstAddress);
      expect(allocator.allocations, 1);
      second.release();
      pool.dispose();
    });

    test('returns the fixed slot address', () {
      final allocator = _TestScratchAllocator();
      final pool = WasmScratchPool(allocator, maxVariableLength: 64);
      final frame = pool.acquire(const [
        ScratchSlotSpec(size: 12, alignment: 4),
      ]);

      expect(frame.fixedAddress(0), allocator.activeAllocations.single);
      frame.release();
      pool.dispose();
    });

    test('uses a different frame for a nested acquisition', () {
      final allocator = _TestScratchAllocator();
      final pool = WasmScratchPool(allocator, maxVariableLength: 64);
      const spec = ScratchSlotSpec(size: 8, alignment: 8);
      final outer = pool.acquire([spec]);
      final inner = pool.acquire([spec]);

      expect(inner.fixed(0).address, isNot(outer.fixed(0).address));
      inner.release();
      outer.release();
      pool.dispose();
    });

    test('keeps outer storage after a deeper nested acquisition', () {
      final allocator = _TestScratchAllocator();
      final pool = WasmScratchPool(allocator, maxVariableLength: 64);
      const spec = ScratchSlotSpec(size: 8, alignment: 8);
      final outer = pool.acquire([spec]);
      final outerAddress = outer.fixed(0).address;
      final middle = pool.acquire([spec]);
      final inner = pool.acquire([spec]);

      expect(outer.fixed(0).address, outerAddress);
      expect(middle.fixed(0).address, isNot(inner.fixed(0).address));
      inner.release();
      middle.release();
      outer.release();
      pool.dispose();
    });

    test('passes runtime size and alignment to fixed allocation', () {
      final allocator = _TestScratchAllocator();
      final pool = WasmScratchPool(allocator, maxVariableLength: 64);

      final frame = pool.acquire(const [
        ScratchSlotSpec(size: 3, alignment: 1),
        ScratchSlotSpec(size: 24, alignment: 16),
      ]);

      expect(allocator.requests, [
        (length: 3, alignment: 1),
        (length: 24, alignment: 16),
      ]);
      expect(frame.fixed(0).address % 1, 0);
      expect(frame.fixed(1).address % 16, 0);
      frame.release();
      pool.dispose();
    });

    test('keeps numeric addresses valid when linear memory grows', () {
      final allocator = _TestScratchAllocator();
      final pool = WasmScratchPool(allocator, maxVariableLength: 64);
      final frame = pool.acquire(const []);
      final before = frame.variable(0, 8);

      allocator.growMemory();

      final after = frame.variable(0, 8);

      expect(after.address, before.address);
      frame.release();
      pool.dispose();
    });

    test('grows variable storage geometrically', () {
      final allocator = _TestScratchAllocator();
      final pool = WasmScratchPool(allocator, maxVariableLength: 64);
      final frame = pool.acquire(const []);

      final first = frame.variable(0, 3);
      final second = frame.variable(0, 5);
      final third = frame.variable(0, 9);

      expect(first.capacity, 4);
      expect(second.capacity, 8);
      expect(third.capacity, 16);
      expect(allocator.allocations, 3);
      frame.release();
      pool.dispose();
    });

    test('returns the variable slot address', () {
      final allocator = _TestScratchAllocator();
      final pool = WasmScratchPool(allocator, maxVariableLength: 64);
      final frame = pool.acquire(const []);

      final address = frame.variableAddress(0, 5);

      expect(address, allocator.activeAllocations.single);
      frame.release();
      pool.dispose();
    });

    test('returns an empty region for a zero-length variable request', () {
      final allocator = _TestScratchAllocator();
      final pool = WasmScratchPool(allocator, maxVariableLength: 64);
      final frame = pool.acquire(const []);

      final region = frame.variable(0, 0);

      expect(region.address, 0);
      expect(region.length, 0);
      expect(region.capacity, 0);
      expect(allocator.allocations, 0);
      frame.release();
      pool.dispose();
    });

    test('releases the old variable allocation before replacing it', () {
      final allocator = _TestScratchAllocator();
      final pool = WasmScratchPool(allocator, maxVariableLength: 64);
      final frame = pool.acquire(const []);
      frame.variable(0, 4);

      frame.variable(0, 9);

      expect(allocator.freedAddresses, [1000]);
      frame.release();
      pool.dispose();
    });

    test('rejects variable length above the configured maximum', () {
      final allocator = _TestScratchAllocator();
      final pool = WasmScratchPool(allocator, maxVariableLength: 8);
      final frame = pool.acquire(const []);

      expect(() => frame.variable(0, 9), throwsA(isA<RangeError>()));
      frame.release();
      pool.dispose();
    });

    test('rejects a negative maximum length', () {
      final allocator = _TestScratchAllocator();

      expect(
        () => WasmScratchPool(allocator, maxVariableLength: -1),
        throwsA(isA<RangeError>()),
      );
    });

    test('rejects an allocator region with invalid alignment', () {
      final allocator = _InvalidScratchAllocator();
      final pool = WasmScratchPool(allocator, maxVariableLength: 64);

      expect(
        () => pool.acquire(const [ScratchSlotSpec(size: 8, alignment: 8)]),
        throwsStateError,
      );
      expect(allocator.freeCalls, 1);
      pool.dispose();
    });

    test('frees an aligned region through its original allocation', () {
      final allocator = _ReleaseMetadataScratchAllocator();
      final pool = WasmScratchPool(allocator, maxVariableLength: 64);

      final frame = pool.acquire(const [
        ScratchSlotSpec(size: 8, alignment: 8),
      ]);
      frame.release();
      pool.dispose();

      expect(allocator.freed, (address: 1000, capacity: 15));
    });

    test('caps geometric growth at the configured maximum', () {
      final allocator = _TestScratchAllocator();
      final pool = WasmScratchPool(allocator, maxVariableLength: 7);
      final frame = pool.acquire(const []);

      final buffer = frame.variable(0, 7);

      expect(buffer.capacity, 7);
      frame.release();
      pool.dispose();
    });

    test('retains variable capacity after release', () {
      final allocator = _TestScratchAllocator();
      final pool = WasmScratchPool(allocator, maxVariableLength: 64);
      final frame = pool.acquire(const []);
      frame.variable(0, 12);
      frame.release();

      final reused = pool.acquire(const []);
      final buffer = reused.variable(0, 1);

      expect(buffer.capacity, 16);
      expect(allocator.allocations, 1);
      reused.release();
      pool.dispose();
    });

    test('warm variable frames perform no new allocator calls', () {
      final allocator = _TestScratchAllocator();
      final pool = WasmScratchPool(allocator, maxVariableLength: 64);
      final first = pool.acquire(const []);
      first.variable(0, 12);
      first.release();
      final warmupAllocations = allocator.allocations;

      useWarmFrame(pool);
      useWarmFrame(pool);
      useWarmFrame(pool);
      useWarmFrame(pool);
      useWarmFrame(pool);
      useWarmFrame(pool);
      useWarmFrame(pool);
      useWarmFrame(pool);

      expect(allocator.allocations, warmupAllocations);
      pool.dispose();
    });

    test('releases a frame when the caller operation throws', () {
      final allocator = _TestScratchAllocator();
      final pool = WasmScratchPool(allocator, maxVariableLength: 64);

      final frame = pool.acquire(const [
        ScratchSlotSpec(size: 16, alignment: 8),
      ]);

      final failure = Exception('operation failed');

      expect(
        () => runWithFrame(frame, () {
          frame.variable(0, 8);
          throw failure;
        }),
        throwsA(same(failure)),
      );

      final reused = pool.acquire(const []);

      expect(reused, same(frame));
      reused.release();
      pool.dispose();
    });

    test('frees every retained allocation exactly once at teardown', () {
      final allocator = _TestScratchAllocator();
      final pool = WasmScratchPool(allocator, maxVariableLength: 64);
      final first = pool.acquire(const [
        ScratchSlotSpec(size: 8, alignment: 8),
      ]);
      first.variable(0, 4);
      first.release();
      final second = pool.acquire(const [
        ScratchSlotSpec(size: 16, alignment: 8),
      ]);
      second.variable(1, 12);
      second.release();

      pool.dispose();
      pool.dispose();

      expect(allocator.freeCalls, 4);
      expect(allocator.activeAllocations, isEmpty);
    });

    test('rejects use after frame release', () {
      final allocator = _TestScratchAllocator();
      final pool = WasmScratchPool(allocator, maxVariableLength: 64);
      final frame = pool.acquire(const []);
      frame.release();

      expect(() => frame.variable(0, 1), throwsA(isA<StateError>()));
      pool.dispose();
    });

    test('rejects release of a non-top frame', () {
      final allocator = _TestScratchAllocator();
      final pool = WasmScratchPool(allocator, maxVariableLength: 64);
      final outer = pool.acquire(const []);
      final inner = pool.acquire(const []);

      expect(outer.release, throwsA(isA<StateError>()));
      inner.release();
      outer.release();
      pool.dispose();
    });
  });
}

final class _TestScratchAllocator implements ScratchAllocator {
  final List<({int length, int alignment})> requests = [];
  final List<int> freedAddresses = [];
  final Set<int> activeAllocations = {};
  var extraCapacity = 0;
  var failAllocation = false;
  late int _nextAddress;
  late int allocations;
  late int freeCalls;
  late int memoryGeneration;

  _TestScratchAllocator() {
    _nextAddress = 1000;
    allocations = 0;
    freeCalls = 0;
    memoryGeneration = 0;
  }

  void growMemory() => memoryGeneration++;

  @override
  ScratchAllocation allocate({required int length, required int alignment}) {
    if (failAllocation) throw StateError('Allocation failed');
    final address = (_nextAddress + alignment - 1) ~/ alignment * alignment;
    final allocation = ScratchAllocation(
      address: address,
      capacity: length + extraCapacity,
    );
    _nextAddress = address + allocation.capacity;
    allocations++;
    activeAllocations.add(allocation.address);
    requests.add((length: length, alignment: alignment));
    return allocation;
  }

  @override
  void free(ScratchAllocation allocation) {
    freeCalls++;
    freedAddresses.add(allocation.address);
    activeAllocations.remove(allocation.address);
  }
}

final class _InvalidScratchAllocator implements ScratchAllocator {
  late int freeCalls;

  _InvalidScratchAllocator() : freeCalls = 0;

  @override
  ScratchAllocation allocate({required int length, required int alignment}) =>
      ScratchAllocation(address: 1, capacity: length);

  @override
  void free(ScratchAllocation allocation) => freeCalls++;
}

final class _ReleaseMetadataScratchAllocator implements ScratchAllocator {
  ({int address, int capacity})? freed;

  @override
  ScratchAllocation allocate({required int length, required int alignment}) =>
      ScratchAllocation(
        address: 1008,
        capacity: length,
        releaseAddress: 1000,
        releaseCapacity: 15,
      );

  @override
  void free(ScratchAllocation allocation) {
    freed = (
      address: allocation.releaseAddress,
      capacity: allocation.releaseCapacity,
    );
  }
}

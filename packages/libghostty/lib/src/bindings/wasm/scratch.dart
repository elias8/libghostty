import '../../generated/libghostty_wasm.g.dart';
import '../../types/types.dart';
import 'allocator.dart';

/// Size and natural alignment of a pointer-sized scalar in the wasm32 ABI.
const wasm32PointerSize = 4;

/// A linear-memory allocation retained by a [WasmScratchPool].
///
/// The allocator owns the storage until [ScratchAllocator.free] is called.
/// The pool never stores a typed memory view for this allocation. Callers must
/// reacquire a current memory view after an export that may grow memory.
final class ScratchAllocation {
  final int address;
  final int capacity;
  final int releaseAddress;
  final int releaseCapacity;

  const ScratchAllocation({
    required this.address,
    required this.capacity,
    int? releaseAddress,
    int? releaseCapacity,
  }) : releaseAddress = releaseAddress ?? address,
       releaseCapacity = releaseCapacity ?? capacity;
}

/// Allocates and releases regions in the WebAssembly module's linear memory.
///
/// Implementations must return a region whose capacity is at least the
/// requested length and whose address satisfies the requested alignment. A
/// returned allocation remains owned by the caller until it is passed to
/// [free] exactly once.
abstract interface class ScratchAllocator {
  ScratchAllocation allocate({required int length, required int alignment});

  void free(ScratchAllocation allocation);
}

/// A region reserved for one operation in a [WasmScratchFrame].
///
/// [length] is the number of bytes currently required by the operation, while
/// [capacity] is the retained allocation size. The address is valid only
/// while its frame is active.
final class ScratchRegion {
  final int address;
  final int length;
  final int capacity;
  final int alignment;

  const ScratchRegion({
    required this.address,
    required this.length,
    required this.capacity,
    required this.alignment,
  });
}

/// Runtime size and alignment for one fixed scratch slot.
final class ScratchSlotSpec {
  final int size;
  final int alignment;

  const ScratchSlotSpec({required this.size, required this.alignment});
}

/// Uses the artifact's generic byte allocator for scratch storage.
final class WasmExportScratchAllocator implements ScratchAllocator {
  final GhosttyExports _exports;

  const WasmExportScratchAllocator(this._exports);

  @override
  ScratchAllocation allocate({required int length, required int alignment}) {
    if (length == 0) return const ScratchAllocation(address: 0, capacity: 0);
    final allocationLength = length + alignment - 1;
    final baseAddress = _exports.allocateBytes(allocationLength);
    if (baseAddress == 0) throw const OutOfMemoryException();
    final address = (baseAddress + alignment - 1) ~/ alignment * alignment;
    return ScratchAllocation(
      address: address,
      capacity: length,
      releaseAddress: baseAddress,
      releaseCapacity: allocationLength,
    );
  }

  @override
  void free(ScratchAllocation allocation) {
    if (allocation.capacity == 0) return;
    _exports.freeBytes(allocation.releaseAddress, allocation.releaseCapacity);
  }
}

/// One active invocation frame owned by a [WasmScratchPool].
///
/// A frame is valid from [WasmScratchPool.acquire] until [release]. It must
/// not be retained across ABI operations or used after release.
final class WasmScratchFrame {
  final WasmScratchPool _pool;
  final List<_FixedScratchSlot> _fixedSlots = [];
  final List<_VariableScratchSlot> _variableSlots = [];
  late bool _active;
  var _needsTrim = false;

  WasmScratchFrame._(this._pool) : _active = false;

  /// Returns the runtime-sized fixed slot at [index].
  ScratchRegion fixed(int index) => _fixedSlot(index).region;

  /// Returns the address of the fixed slot at [index].
  ///
  /// The address is valid while this frame is active.
  int fixedAddress(int index) => _fixedSlot(index).allocation?.address ?? 0;

  /// Releases this frame while retaining its allocated capacity for reuse.
  ///
  /// Retained capacity remains available to the next acquisition. Releasing
  /// the same frame more than once is harmless; nested frames must be released
  /// in reverse acquisition order.
  void release() => _pool._release(this);

  /// Returns a variable byte region with at least [length] bytes.
  ///
  /// Capacity grows geometrically up to the pool's configured maximum. The
  /// optional [alignment] is recorded with the retained allocation and must
  /// be supplied consistently for subsequent uses of the same slot unless a
  /// new allocation is required.
  ScratchRegion variable(int index, int length, {int alignment = 1}) {
    final slot = _configureVariable(index, length, alignment);
    return slot.region;
  }

  /// Returns the address of a variable byte region with at least [length]
  /// bytes.
  ///
  /// The address is valid while this frame is active.
  int variableAddress(int index, int length, {int alignment = 1}) {
    return _configureVariable(index, length, alignment).allocation?.address ??
        0;
  }

  ScratchAllocation _allocate({required int length, required int alignment}) {
    final allocation = _pool._allocator.allocate(
      length: length,
      alignment: alignment,
    );
    if (allocation.capacity < length ||
        allocation.address < 0 ||
        allocation.address % alignment != 0) {
      _pool._allocator.free(allocation);
      throw StateError('Scratch allocator returned an invalid allocation');
    }
    return allocation;
  }

  int _capacityFor(_VariableScratchSlot slot, int length, int alignment) {
    final maxLength = _pool.maxVariableLength;
    if (length > maxLength) {
      throw RangeError.range(length, 0, maxLength, 'length');
    }
    if (length <= slot.capacity && alignment == slot.alignment) {
      return slot.capacity;
    }
    if (length == 0 && slot.capacity == 0) return 0;

    var capacity = slot.capacity == 0 ? 1 : slot.capacity;
    while (capacity < length) {
      if (capacity > maxLength ~/ 2) {
        capacity = maxLength;
        break;
      }
      capacity *= 2;
    }
    if (capacity < length) {
      throw RangeError.range(length, 0, maxLength, 'length');
    }
    return capacity;
  }

  void _checkActive() {
    if (!_active) throw StateError('Scratch frame is not active');
  }

  void _configure(List<ScratchSlotSpec> specs) {
    if (specs.isEmpty && _fixedSlots.isEmpty) return;
    final replacements = <ScratchAllocation>[];
    final configured = <_FixedScratchSlot>[];
    try {
      for (var index = 0; index < specs.length; index++) {
        final spec = specs[index];
        _validateSpec(spec, index);
        final existing = index < _fixedSlots.length ? _fixedSlots[index] : null;
        if (existing != null &&
            existing.size == spec.size &&
            existing.alignment == spec.alignment) {
          configured.add(existing);
        } else {
          configured.add(_FixedScratchSlot._allocate(_pool._allocator, spec));
          if (existing?.allocation case final allocation?) {
            replacements.add(allocation);
          }
        }
      }
    } catch (_) {
      for (final slot in configured) {
        if (slot.allocation case final allocation?) {
          final isExisting = _fixedSlots.contains(slot);
          if (!isExisting) _pool._allocator.free(allocation);
        }
      }
      rethrow;
    }

    for (var index = specs.length; index < _fixedSlots.length; index++) {
      if (_fixedSlots[index].allocation case final allocation?) {
        replacements.add(allocation);
      }
    }
    _fixedSlots
      ..clear()
      ..addAll(configured);
    for (final allocation in replacements) {
      _pool._allocator.free(allocation);
    }
  }

  _VariableScratchSlot _configureVariable(
    int index,
    int length,
    int alignment,
  ) {
    _checkActive();
    _validateIndex(index);
    if (length < 0) throw RangeError.range(length, 0, null, 'length');
    if (alignment < 1) {
      throw RangeError.range(alignment, 1, null, 'alignment');
    }
    final slot = _variableSlot(index);
    final capacity = _capacityFor(slot, length, alignment);
    if (capacity != slot.capacity || alignment != slot.alignment) {
      _replaceVariableAllocation(slot, capacity, alignment);
    }
    slot.length = length;
    return slot;
  }

  void _disposeAllocations() {
    for (final slot in _fixedSlots) {
      if (slot.allocation case final allocation?) {
        _pool._allocator.free(allocation);
      }
    }
    for (final slot in _variableSlots) {
      if (slot.allocation case final allocation?) {
        _pool._allocator.free(allocation);
      }
    }
    _fixedSlots.clear();
    _variableSlots.clear();
  }

  void _trimVariableAllocations() {
    if (!_needsTrim) return;
    for (var i = 0; i < _variableSlots.length; i++) {
      final slot = _variableSlots[i];
      if (i >= _pool.maxRetainedVariableSlots ||
          slot.capacity > _pool.maxRetainedVariableLength) {
        if (slot.allocation case final allocation?) {
          _pool._allocator.free(allocation);
        }
        slot
          ..allocation = null
          ..length = 0;
      }
    }
    if (_variableSlots.length > _pool.maxRetainedVariableSlots) {
      _variableSlots.length = _pool.maxRetainedVariableSlots;
    }
    _needsTrim = false;
  }

  _FixedScratchSlot _fixedSlot(int index) {
    _checkActive();
    if (index < 0 || index >= _fixedSlots.length) {
      throw RangeError.index(index, _fixedSlots, 'index');
    }
    return _fixedSlots[index];
  }

  void _replaceVariableAllocation(
    _VariableScratchSlot slot,
    int capacity,
    int alignment,
  ) {
    if (capacity == 0) {
      if (slot.allocation case final allocation?) {
        _pool._allocator.free(allocation);
      }
      slot
        ..allocation = null
        ..alignment = alignment
        ..length = 0;
      return;
    }
    final allocation = _allocate(length: capacity, alignment: alignment);
    if (allocation.capacity > _pool.maxRetainedVariableLength) {
      _needsTrim = true;
    }
    final old = slot.allocation;
    slot
      ..allocation = allocation
      ..alignment = alignment;
    if (old case final oldAllocation?) {
      _pool._allocator.free(oldAllocation);
    }
  }

  void _validateIndex(int index) {
    if (index < 0) throw RangeError.index(index, _variableSlots, 'index');
  }

  _VariableScratchSlot _variableSlot(int index) {
    while (_variableSlots.length <= index) {
      _variableSlots.add(_VariableScratchSlot());
      if (_variableSlots.length > _pool.maxRetainedVariableSlots) {
        _needsTrim = true;
      }
    }
    return _variableSlots[index];
  }

  static void _validateSpec(ScratchSlotSpec spec, int index) {
    if (spec.size < 0) {
      throw RangeError.range(spec.size, 0, null, 'fixedSlots[$index].size');
    }
    if (spec.alignment < 1) {
      throw RangeError.range(
        spec.alignment,
        1,
        null,
        'fixedSlots[$index].alignment',
      );
    }
  }
}

/// Reusable, reentrant WebAssembly scratch storage.
///
/// The pool retains allocations between calls and creates a distinct frame
/// for every active nesting depth. Acquire a frame around one ABI operation
/// and always release it in a `finally` clause:
///
/// ```dart
/// final frame = pool.acquire(layoutSlots);
/// try {
///   final output = frame.fixed(0);
///   // Invoke the ABI and refresh the memory view before reading output.
/// } finally {
///   frame.release();
/// }
/// ```
final class WasmScratchPool {
  static const defaultMaxVariableLength = 1 << 30;

  final ScratchAllocator _allocator;
  final int maxVariableLength;
  final int maxRetainedVariableLength;
  final int maxRetainedVariableSlots;
  final _frames = <WasmScratchFrame>[];
  late int _activeDepth;
  late bool _disposed;

  WasmScratchPool(
    this._allocator, {
    required this.maxVariableLength,
    this.maxRetainedVariableLength = 64 * 1024,
    this.maxRetainedVariableSlots = 16,
  }) {
    _activeDepth = 0;
    _disposed = false;
    if (maxVariableLength < 0) {
      throw RangeError.range(maxVariableLength, 0, null, 'maxVariableLength');
    }
    RangeError.checkNotNegative(
      maxRetainedVariableLength,
      'maxRetainedVariableLength',
    );
    RangeError.checkNotNegative(
      maxRetainedVariableSlots,
      'maxRetainedVariableSlots',
    );
  }

  /// Acquires the frame at the current nesting depth.
  ///
  /// [fixedSlots] must contain sizes and alignments read from validated
  /// runtime metadata. The list is consumed during acquisition and is not
  /// retained by the pool.
  WasmScratchFrame acquire(List<ScratchSlotSpec> fixedSlots) {
    _checkUsable();
    final frame = _activeDepth < _frames.length
        ? _frames[_activeDepth]
        : WasmScratchFrame._(this);
    if (_activeDepth == _frames.length) _frames.add(frame);

    frame._configure(fixedSlots);
    frame._active = true;
    _activeDepth++;
    return frame;
  }

  /// Releases every retained allocation. Repeated calls are harmless.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _activeDepth = 0;
    for (final frame in _frames) {
      frame._active = false;
      frame._disposeAllocations();
    }
  }

  void _checkUsable() {
    if (_disposed) throw StateError('Scratch pool is disposed');
  }

  void _release(WasmScratchFrame frame) {
    if (!frame._active) return;
    if (_disposed) {
      frame._active = false;
      return;
    }
    if (_activeDepth == 0 || !identical(frame, _frames[_activeDepth - 1])) {
      throw StateError('Scratch frames must be released in reverse order');
    }
    frame._trimVariableAllocations();
    frame._active = false;
    _activeDepth--;
  }
}

final class _FixedScratchSlot {
  final int size;
  final int alignment;
  final ScratchAllocation? allocation;

  const _FixedScratchSlot._(this.size, this.alignment, this.allocation);

  factory _FixedScratchSlot._allocate(
    ScratchAllocator allocator,
    ScratchSlotSpec spec,
  ) {
    if (spec.size == 0) return _FixedScratchSlot._(0, spec.alignment, null);
    final allocation = allocator.allocate(
      length: spec.size,
      alignment: spec.alignment,
    );
    if (allocation.capacity < spec.size ||
        allocation.address < 0 ||
        allocation.address % spec.alignment != 0) {
      allocator.free(allocation);
      throw StateError('Scratch allocator returned an invalid allocation');
    }
    return _FixedScratchSlot._(spec.size, spec.alignment, allocation);
  }

  ScratchRegion get region => ScratchRegion(
    address: allocation?.address ?? 0,
    length: size,
    capacity: allocation?.capacity ?? 0,
    alignment: alignment,
  );
}

final class _VariableScratchSlot {
  ScratchAllocation? allocation;
  late int alignment;
  late int length;

  _VariableScratchSlot() {
    alignment = 1;
    length = 0;
  }

  int get capacity => allocation?.capacity ?? 0;

  ScratchRegion get region => ScratchRegion(
    address: allocation?.address ?? 0,
    length: length,
    capacity: capacity,
    alignment: alignment,
  );
}

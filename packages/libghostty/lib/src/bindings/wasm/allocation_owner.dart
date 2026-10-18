import '../../generated/libghostty_wasm.g.dart';
import '../../types/types.dart';
import 'allocator.dart';

final class WasmAllocationOwner {
  final GhosttyExports _exports;
  final _allocations = <(int, int)>[];

  WasmAllocationOwner(this._exports);

  int allocate(int length) {
    final pointer = _exports.allocateBytes(length);
    if (pointer == 0) throw const OutOfMemoryException();
    _allocations.add((pointer, length));
    return pointer;
  }

  void commit() => _allocations.clear();

  void rollback() {
    for (var i = _allocations.length - 1; i >= 0; i--) {
      final (pointer, length) = _allocations[i];
      _exports.freeBytes(pointer, length);
    }
    _allocations.clear();
  }
}

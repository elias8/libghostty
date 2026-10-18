import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../generated/libghostty_wasm.g.dart';

extension _ExactDataView on JSDataView {
  external JSBigInt getBigUint64(int byteOffset, JSBoolean littleEndian);
}

final class Memory {
  final GhosttyExports _exports;
  JSArrayBuffer? _bufferObject;
  late ByteBuffer _buffer;
  late ByteData _byteData;
  late Uint8List _bytes;
  late int _refreshCount;

  Memory(this._exports) : _refreshCount = 0;

  @visibleForTesting
  int get refreshCount => _refreshCount;

  ByteData get view {
    _refresh();
    return _byteData;
  }

  Uint8List readBytes(int addr, int len) {
    _refresh();
    _checkRange(addr, len);
    return _bytes.buffer.asUint8List(addr, len);
  }

  String readCString(int addr) {
    if (addr == 0) return '';
    _refresh();
    if (addr < 0 || addr >= _bytes.length) {
      throw StateError(
        'Invalid WebAssembly C string address: $addr '
        '(memory length ${_bytes.length})',
      );
    }
    final bytes = <int>[];
    for (var offset = addr; offset < _bytes.length; offset++) {
      final byte = _bytes[offset];
      if (byte == 0) {
        return utf8.decode(bytes);
      }
      bytes.add(byte);
    }
    throw StateError('Unterminated WebAssembly C string at address $addr');
  }

  double readF32(int addr) => view.getFloat32(addr, .little);

  int readI32(int addr) => view.getInt32(addr, .little);

  int readPtr(int addr) => readU32(addr);

  int readU16(int addr) => view.getUint16(addr, .little);

  int readU32(int addr) => view.getUint32(addr, .little);

  int readU64(int addr) {
    final lo = view.getUint32(addr, .little);
    final hi = view.getUint32(addr + 4, .little);
    // Uses multiplication by 2^32 instead of << 32 because JS
    // bitwise operators truncate to 32 bits.
    return lo + hi * 0x100000000;
  }

  JSBigInt readU64BigInt(int addr) {
    _refresh();
    _checkRange(addr, 8);
    return _byteData.toJS.getBigUint64(addr, true.toJS);
  }

  int readU8(int addr) => view.getUint8(addr);

  void writeBytes(int addr, List<int> bytes) {
    _refresh();
    _checkRange(addr, bytes.length);
    _bytes.buffer.asUint8List(addr, bytes.length).setAll(0, bytes);
  }

  void writeF32(int addr, double val) => view.setFloat32(addr, val, .little);

  void writeF64(int addr, double val) => view.setFloat64(addr, val, .little);

  void writeI32(int addr, int val) => view.setInt32(addr, val, .little);

  void writePtr(int addr, int val) => writeU32(addr, val);

  void writeU16(int addr, int val) => view.setUint16(addr, val, .little);

  void writeU32(int addr, int val) => view.setUint32(addr, val, .little);

  void writeU64(int addr, int val) {
    view.setUint32(addr, val & 0xffffffff, .little);
    view.setUint32(addr + 4, val ~/ 0x100000000, .little);
  }

  void writeU8(int addr, int val) => view.setUint8(addr, val);

  void _checkRange(int addr, int length) {
    if (addr < 0 || length < 0 || addr > _bytes.length - length) {
      throw StateError(
        'WebAssembly memory range is out of bounds: address=$addr, '
        'length=$length, memory length=${_bytes.length}',
      );
    }
  }

  void _refresh() {
    final bufferObject = _exports.memory['buffer']! as JSArrayBuffer;
    if (identical(bufferObject, _bufferObject)) return;
    // WebAssembly.Memory.grow replaces and detaches the old ArrayBuffer. Never
    // retain a typed view across that identity change.
    _bufferObject = bufferObject;
    _buffer = bufferObject.toDart;
    _byteData = JSDataView(bufferObject).toDart;
    _bytes = _buffer.asUint8List();
    _refreshCount++;
  }
}

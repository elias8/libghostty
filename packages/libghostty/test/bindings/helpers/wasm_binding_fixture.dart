import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:libghostty/src/bindings/wasm/adapter.dart';
import 'package:libghostty/src/bindings/wasm/layouts.dart';
import 'package:libghostty/src/bindings/wasm/memory.dart';
import 'package:libghostty/src/generated/libghostty_wasm.g.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

@JS('WebAssembly.instantiate')
external JSPromise _instantiate(JSArrayBuffer bytes, JSObject imports);

final class WasmBindingFixture {
  late Layouts layout;
  late StreamChannel<Object?> _assetChannel;

  Future<void> load() async {
    _assetChannel = spawnHybridUri('/test/helpers/asset_server.dart');
    final portValue = await _assetChannel.stream.first;
    if (portValue is! double) {
      throw StateError('Asset server returned no port.');
    }
    final port = portValue.toInt();
    final response = await web.window
        .fetch('http://localhost:$port/lib/src/wasm/libghostty.wasm'.toJS)
        .toDart;
    final env = newJsObject()..['log'] = ((JSNumber _, JSNumber _) {}).toJS;
    final imports = newJsObject()..['env'] = env;
    final result =
        (await _instantiate(
              await response.arrayBuffer().toDart,
              imports,
            ).toDart)!
            as JSObject;
    final instance = result['instance']! as JSObject;
    final exports = GhosttyExports(instance['exports']! as JSObject);
    layout = Layouts.fromJson(
      Memory(exports).readCString(exports.ghostty_type_json()),
    );
  }

  Future<void> close() => _assetChannel.sink.close();
}

final class FaultExports {
  final memory = web.Memory(web.MemoryDescriptor(initial: 8, maximum: 16));
  final object = newJsObject();
  final allocations = <(int, int)>[];
  final frees = <(int, int)>[];
  var _nextAddress = 1024;
  var attempts = 0;
  int? failAt;
  var poisonAllocations = false;

  late final GhosttyExports exports;

  FaultExports() {
    object['memory'] = memory;
    object['ghostty_wasm_alloc'] = (JSNumber size) {
      final length = size.toDartInt;
      attempts++;
      if (attempts == failAt) return 0.toJS;
      final pointer = _nextAddress;
      allocations.add((pointer, length));
      if (poisonAllocations) {
        Memory(
          exports,
        ).writeBytes(pointer, Uint8List(length)..fillRange(0, length, 0xff));
      }
      _nextAddress = (_nextAddress + length + 15) ~/ 16 * 16;
      return pointer.toJS;
    }.toJS;
    object['ghostty_wasm_free'] = (JSNumber pointer, JSNumber length) {
      frees.add((pointer.toDartInt, length.toDartInt));
    }.toJS;
    exports = GhosttyExports(object);
  }
}

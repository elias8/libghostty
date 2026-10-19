@TestOn('browser')
library;

import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:libghostty/src/bindings/wasm/adapter.dart' show newJsObject;
import 'package:libghostty/src/bindings/wasm/loader.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

final _startTrapModule = base64Decode(
  'AGFzbQEAAAABBAFgAAACDQEDZW52BXRvdWNoAAADAgEACAEBCgcBBQAQAAAL',
);

final _memoryModule = base64Decode('AGFzbQEAAAAFAwEAAQcKAQZtZW1vcnkCAA==');

void main() {
  for (final mime in ['application/wasm', 'application/octet-stream']) {
    test('instantiates a memory export with $mime', () async {
      final response = web.Response(
        _memoryModule.toJS,
        web.ResponseInit(headers: {'Content-Type': mime}.jsify()! as JSObject),
      );
      final instance = await instantiateArtifact(response, newJsObject());
      final exports = instance['exports']! as JSObject;
      final memory = exports['memory']! as JSObject;
      final buffer = memory['buffer']! as JSArrayBuffer;
      expect(buffer.toDart.lengthInBytes, 65536);
    });
  }

  test(
    'falls back after compile streaming consumes the response and fails',
    () async {
      final original = _compileStreamingFunction;
      addTearDown(() => _compileStreamingFunction = original);
      _compileStreamingFunction = ((web.Response response) {
        return _consumeAndReject(response).toJS;
      }).toJS;
      final response = web.Response(
        _memoryModule.toJS,
        web.ResponseInit(
          headers: {'Content-Type': 'application/wasm'}.jsify()! as JSObject,
        ),
      );
      final instance = await instantiateArtifact(response, newJsObject());
      final exports = instance['exports']! as JSObject;
      final memory = exports['memory']! as JSObject;
      final buffer = memory['buffer']! as JSArrayBuffer;
      expect(buffer.toDart.lengthInBytes, 65536);
    },
  );

  test(
    'does not retry a module that fails while running its start function',
    () async {
      var calls = 0;
      final env = newJsObject()..['touch'] = (() => calls++).toJS;
      final imports = newJsObject()..['env'] = env;
      final response = web.Response(
        _startTrapModule.toJS,
        web.ResponseInit(
          headers: {'Content-Type': 'application/wasm'}.jsify()! as JSObject,
        ),
      );

      await expectLater(
        instantiateArtifact(response, imports),
        throwsA(anything),
      );
      expect(calls, 1);
    },
  );

  test('invalid Wasm still fails after the streaming fallback', () async {
    final response = web.Response(
      Uint8List.fromList([1, 2, 3]).toJS,
      web.ResponseInit(
        headers: {'Content-Type': 'application/wasm'}.jsify()! as JSObject,
      ),
    );
    await expectLater(
      instantiateArtifact(response, newJsObject()),
      throwsA(anything),
    );
  });
}

Future<JSObject> _consumeAndReject(web.Response response) async {
  await response.arrayBuffer().toDart;
  throw StateError('compilation failed after consuming the body');
}

@JS('WebAssembly.compileStreaming')
external JSAny? get _compileStreamingFunction;

@JS('WebAssembly.compileStreaming')
external set _compileStreamingFunction(JSAny? value);

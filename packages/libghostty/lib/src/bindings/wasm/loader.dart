import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<JSObject> instantiateArtifact(web.Response response, JSObject imports) {
  return _compileArtifact(
    response,
  ).then((module) => _instantiateModule(module, imports).toDart);
}

Future<JSObject> _compileArtifact(web.Response response) async {
  final mime = response.headers.get('Content-Type')?.split(';').first.trim();
  late final JSObject module;
  if (mime?.toLowerCase() == 'application/wasm' &&
      _compileStreamingFunction.isA<JSFunction>()) {
    final fallback = response.clone();
    try {
      module = await _compileStreaming(response).toDart;
    } on Object {
      module = await _compileBytes(fallback);
    }
  } else {
    module = await _compileBytes(response);
  }
  return module;
}

Future<JSObject> _compileBytes(web.Response response) {
  return response.arrayBuffer().toDart.then((bytes) => _compile(bytes).toDart);
}

@JS('WebAssembly.compileStreaming')
external JSAny? get _compileStreamingFunction;

@JS('WebAssembly.compileStreaming')
external JSPromise<JSObject> _compileStreaming(web.Response response);

@JS('WebAssembly.compile')
external JSPromise<JSObject> _compile(JSArrayBuffer bytes);

@JS('WebAssembly.instantiate')
external JSPromise<JSObject> _instantiateModule(
  JSObject module,
  JSObject imports,
);

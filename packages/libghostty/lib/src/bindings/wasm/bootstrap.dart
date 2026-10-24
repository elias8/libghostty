import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import '../../generated/libghostty_wasm.g.dart';
import '../bindings.dart' as registry;
import '../formatter/wasm.dart' as formatter;
import '../key/wasm.dart' as key;
import '../kitty_graphics/wasm.dart' as kitty_graphics;
import '../mouse/wasm.dart' as mouse;
import '../parser/wasm.dart' as parser;
import '../render/wasm.dart' as render;
import '../search/wasm.dart' as search;
import '../selection/wasm.dart' as selection;
import '../snapshot/wasm.dart' as snapshot;
import '../system/wasm.dart' as system;
import '../terminal/wasm.dart' as terminal;
import '../utility/wasm.dart' as utility;
import '../wasm.dart' as platform;
import 'adapter.dart';
import 'layouts.dart';
import 'loader.dart';
import 'memory.dart';

Future<void>? _initializationFuture;
Uri? _initializationUri;
Uri? _initializedUri;

/// Loads a libghostty WebAssembly artifact and installs all focused bindings.
///
/// The artifact's own `ghostty_type_json` metadata is parsed before any
/// adapter is published. Missing or incompatible metadata therefore fails
/// initialization without leaving a partially initialized binding set.
/// Throws [StateError] when the fetch completes with an unsuccessful HTTP
/// status, the memory export is absent, metadata is incompatible, or
/// initialization conflicts with a previous or concurrent initialization.
///
/// ```dart
/// await initializeForWeb(Uri.parse('libghostty.wasm'));
/// ```
Future<void> initializeForWeb(Uri wasmUri) {
  final initializedUri = _initializedUri;
  if (initializedUri != null) {
    if (initializedUri != wasmUri) {
      throw StateError(
        'libghostty WebAssembly is already initialized from $initializedUri.',
      );
    }
    return Future<void>.value();
  }

  final initializationFuture = _initializationFuture;
  if (initializationFuture != null) {
    if (_initializationUri != wasmUri) {
      throw StateError(
        'libghostty WebAssembly initialization is already in progress for '
        '$_initializationUri.',
      );
    }
    return initializationFuture;
  }

  _initializationUri = wasmUri;
  final future = _initialize(wasmUri);
  _initializationFuture = future;
  return future;
}

JSObject _buildImports() {
  final env = newJsObject()..['log'] = ((JSNumber _, JSNumber _) {}).toJS;
  return newJsObject()..['env'] = env;
}

Future<void> _initialize(Uri wasmUri) async {
  try {
    final response = await web.window.fetch(wasmUri.toString().toJS).toDart;
    if (!response.ok) {
      throw StateError(
        'Unable to fetch libghostty WebAssembly from $wasmUri '
        '(HTTP ${response.status}).',
      );
    }
    final instance = await instantiateArtifact(response, _buildImports());
    final exportsObject = instance['exports']! as JSObject;
    _requireExports(exportsObject);
    final exports = GhosttyExports(exportsObject);
    final layout = Layouts.fromJson(
      Memory(exports).readCString(exports.ghostty_type_json()),
    );

    platform.bindings = registry.Bindings(
      key: key.WasmKeyBindings(exports),
      mouse: mouse.WasmMouseBindings(exports, layout),
      snapshot: snapshot.WasmSnapshotBindings(exports),
      parser: parser.WasmParserBindings(exports, layout),
      render: render.WasmRenderBindings(exports, layout),
      system: system.WasmSystemBindings(exports, layout),
      utility: utility.WasmUtilityBindings(exports, layout),
      terminal: terminal.WasmTerminalBindings(exports, layout),
      selection: selection.WasmSelectionBindings(exports, layout),
      formatter: formatter.WasmFormatterBindings(exports, layout),
      kittyGraphics: kitty_graphics.WasmKittyGraphicsBindings(exports, layout),
      search: search.WasmSearchBindings(exports, layout),
    );
    _initializedUri = wasmUri;
  } catch (_) {
    _initializationUri = null;
    _initializationFuture = null;
    rethrow;
  }
  _initializationUri = null;
  _initializationFuture = null;
}

void _requireExports(JSObject exports) {
  if (!exports['memory'].isA<JSObject>()) {
    throw StateError('libghostty WebAssembly export is missing: memory');
  }
}

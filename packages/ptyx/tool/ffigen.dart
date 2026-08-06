/// Generates PTYX FFI bindings from the public C headers.
///
/// Usage:
///   cd packages/ptyx
///   dart run tool/ffigen.dart
library;

import 'dart:io';

import 'package:ffigen/ffigen.dart';
import 'package:logging/logging.dart';

const _nativeOutput = 'lib/src/ffi/ptyx.g.dart';

void main() {
  Logger.root.onRecord.listen((record) => stderr.writeln(record));

  try {
    _createGenerator().generate(logger: Logger.root);
    _markGeneratedLibraryInternal();
  } on Object catch (error, stackTrace) {
    stderr.writeln('Failed to generate bindings: $error\n$stackTrace');
    exit(1);
  }
}

void _markGeneratedLibraryInternal() {
  final file = File(_nativeOutput);
  var text = file.readAsStringSync();
  text = text.replaceFirst(
    "@ffi.DefaultAsset('package:ptyx/ptyx.dart')",
    "@internal\n@ffi.DefaultAsset('package:ptyx/ptyx.dart')",
  );
  text = text.replaceFirst(
    "import 'dart:ffi' as ffi;",
    "import 'dart:ffi' as ffi;\nimport 'package:meta/meta.dart' show internal;",
  );
  file.writeAsStringSync(text);
}

FfiGenerator _createGenerator() => FfiGenerator(
  output: Output(
    dartFile: Uri.file(_nativeOutput),
    preamble: '// ignore_for_file: unused_field, type=lint',
    style: const NativeExternalBindings(assetId: 'package:ptyx/ptyx.dart'),
  ),
  headers: Headers(
    entryPoints: [Uri.file('include/ptyx.h')],
    include: (header) =>
        header.path.endsWith('/include/ptyx.h') ||
        header.path == 'include/ptyx.h',
    compilerOptions: [...defaultCompilerOpts(Logger.root), '-Iinclude'],
  ),
  functions: Functions(
    include: (declaration) {
      final name = declaration.originalName;
      return name.startsWith('ptyx_');
    },
  ),
  structs: const Structs(include: _includePtyxType, rename: _stripSuffix),
  typedefs: const Typedefs(include: _includePtyxType, rename: _stripSuffix),
  globals: const Globals(include: _includePtyxType),
  macros: const Macros(include: _includePtyxType),
);

bool _includePtyxType(Declaration declaration) {
  final name = declaration.originalName;
  return name.startsWith('ptyx_') ||
      name.startsWith('PTYX_') ||
      name.startsWith('UINT');
}

String _stripSuffix(Declaration declaration) {
  final name = declaration.originalName;
  if (name.startsWith('ptyx_') && name.endsWith('_t')) {
    return name.substring(5, name.length - 2);
  }
  return name;
}

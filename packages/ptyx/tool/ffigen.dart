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

Future<void> main() async {
  Logger.root.onRecord.listen((record) => stderr.writeln(record));

  try {
    await _createGenerator().generate(logger: Logger.root);
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
    dart: DartOutput(path: Uri.file(_nativeOutput)),
    preamble: '// ignore_for_file: unused_field, type=lint',
    style: const NativeExternalBindings(assetId: 'package:ptyx/ptyx.dart'),
  ),
  input: Input(
    entryPoints: [Uri.file('include/ptyx.h')],
    include: (header) =>
        header.path.endsWith('/include/ptyx.h') ||
        header.path == 'include/ptyx.h',
    compilerOptions: ['-Iinclude'],
    appendCompilerOptions: true,
  ),
  visitors: [
    Visitor(
      func: (declaration) {
        declaration.isIncluded = declaration.originalName.startsWith('ptyx_');
      },
      struct: (declaration) {
        declaration.isIncluded = _includePtyxType(declaration);
        declaration.name = _stripSuffix(declaration);
      },
      typealias: (declaration) {
        declaration.isIncluded = _includePtyxType(declaration)
            ? TypealiasInclude.ifUsed
            : TypealiasInclude.never;
        declaration.name = _stripSuffix(declaration);
      },
      global: (declaration) {
        declaration.isIncluded = _includePtyxType(declaration);
      },
      macroConstant: (declaration) {
        declaration.isIncluded = _includePtyxType(declaration);
      },
    ),
  ],
);

bool _includePtyxType(NamedNode declaration) {
  final name = declaration.originalName;
  return name.startsWith('ptyx_') ||
      name.startsWith('PTYX_') ||
      name.startsWith('UINT');
}

String _stripSuffix(NamedNode declaration) {
  final name = declaration.originalName;
  if (name.startsWith('ptyx_') && name.endsWith('_t')) {
    return name.substring(5, name.length - 2);
  }
  return name;
}

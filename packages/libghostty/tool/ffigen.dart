/// Generates FFI bindings and WASM typed exports from ghostty-vt headers.
///
/// Usage:
///   cd packages/libghostty
///   dart run tool/ffigen.dart
library;

import 'dart:io';

import 'package:ffigen/ffigen.dart';
import 'package:logging/logging.dart';

import 'ffigen/enums.dart';
import 'ffigen/naming.dart';
import 'ffigen/wasm_exports.dart';

const _nativeOutput = 'lib/src/generated/libghostty.g.dart';
const _enumsOutput = 'lib/src/generated/libghostty_enums.g.dart';
const _wasmOutput = 'lib/src/generated/libghostty_wasm.g.dart';
const _headerPath = '../../ghostty/include/ghostty/vt.h';

const _compilerOpts = ['-I../../ghostty/include'];

Future<void> main() async {
  Logger.root.onRecord.listen((r) => stderr.writeln(r));

  if (!File(_headerPath).existsSync()) {
    stderr.writeln(
      'Missing ffigen entry-point header: $_headerPath. '
      'Run this command from packages/libghostty with the Ghostty checkout at ../../ghostty.',
    );
    exit(1);
  }

  try {
    await _createGenerator().generate(logger: Logger.root);
  } on Object catch (e, s) {
    stderr.writeln('Failed to generate bindings: $e\n$s');
    exit(1);
  }

  try {
    extractEnums(
      bindingsPath: _nativeOutput,
      enumsPath: _enumsOutput,
      docPrefix: 'Ghostty',
      stripMembers: [
        // C ABI sentinels (GHOSTTY_*_MAX_VALUE = INT_MAX) force enum sizing
        // but have no meaning in Dart and break exhaustive switches.
        (
          member: RegExp(r',\n\s+\w+\(2147483647\);'),
          fromValueCase: RegExp(r'\n\s+2147483647 => \w+,'),
        ),
      ],
    );
  } on Object catch (e, s) {
    stderr.writeln('Failed to extract enums: $e\n$s');
    exit(1);
  }

  try {
    generateWasmExports(
      generator: _createGenerator(compilerOpts: ['-D__wasm__']),
      outputPath: _wasmOutput,
      typeName: 'GhosttyExports',
    );
  } on Object catch (e, s) {
    stderr.writeln('Failed to generate WASM exports: $e\n$s');
    exit(1);
  }
}

Input _headers({List<String> compilerOpts = const []}) => Input(
  entryPoints: [Uri.file(_headerPath)],
  include: (header) {
    final path = header.path;
    return path.contains('ghostty/vt.h') || path.contains('ghostty/vt/');
  },
  compilerOptions: [..._compilerOpts, ...compilerOpts],
  appendCompilerOptions: true,
);

const _nonLeafFunctions = {
  'ghostty_terminal_resize',
  'ghostty_terminal_vt_write',
  'ghostty_terminal_continuation_write',
  'ghostty_terminal_paste',
  'ghostty_terminal_set',
};

FfiGenerator _createGenerator({List<String> compilerOpts = const []}) =>
    FfiGenerator(
      output: Output(
        dart: DartOutput(path: Uri.file(_nativeOutput)),
        preamble: '// ignore_for_file: unused_field',
        style: const NativeExternalBindings(
          assetId: 'package:libghostty/libghostty.dart',
        ),
      ),
      input: _headers(compilerOpts: compilerOpts),
      visitors: [
        Visitor(
          func: (declaration) {
            declaration.isIncluded = declaration.originalName.startsWith(
              'ghostty_',
            );
            declaration.isLeaf = !_nonLeafFunctions.contains(
              declaration.originalName,
            );
          },
          union: (declaration) {
            declaration.isIncluded = _includeType(declaration);
            declaration.name = _stripPrefix(declaration);
          },
          struct: (declaration) {
            declaration.isIncluded = _includeType(declaration);
            declaration.name = _stripPrefix(declaration);
          },
          typealias: (declaration) {
            declaration.isIncluded = _includeType(declaration)
                ? TypealiasInclude.ifUsed
                : TypealiasInclude.never;
            declaration.name = _stripPrefix(declaration);
          },
          enumClass: (declaration) {
            declaration.isIncluded = _includeType(declaration);
            declaration.name = _stripPrefix(declaration);
            if (!declaration.isIncluded) return;
            final members = [
              for (final constant in declaration.constants)
                constant.originalName,
            ];
            final prefix = longestCommonPrefix(members);
            for (final constant in declaration.constants) {
              final name = constant.originalName;
              constant.name = toCamelCase(
                prefix.isNotEmpty && name.startsWith(prefix)
                    ? name.substring(prefix.length)
                    : name,
              );
            }
          },
        ),
      ],
    );

bool _includeType(NamedNode d) => d.originalName.startsWith('Ghostty');

String _stripPrefix(NamedNode d) => d.originalName.replaceFirst('Ghostty', '');

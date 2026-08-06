/// Generates FFI bindings and WASM typed exports from ghostty-vt headers.
///
/// Usage:
///   cd packages/libghostty
///   dart run tool/ffigen.dart
library;

import 'dart:io';

import 'package:ffigen/ffigen.dart';
import 'package:ffigen/src/code_generator.dart';
import 'package:ffigen/src/context.dart';
import 'package:ffigen/src/header_parser.dart' as ffigen;
import 'package:logging/logging.dart';

import 'ffigen/enums.dart';
import 'ffigen/naming.dart';
import 'ffigen/wasm_exports.dart';

const _nativeOutput = 'lib/src/ffi/libghostty.g.dart';
const _enumsOutput = 'lib/src/ffi/libghostty_enums.g.dart';
const _wasmOutput = 'lib/src/ffi/libghostty_wasm.g.dart';

const _compilerOpts = ['-I../../ghostty/include'];

void main() {
  Logger.root.onRecord.listen((r) => stderr.writeln(r));

  final renames = _extractEnumMemberRenames();

  try {
    _createGenerator(enumMemberRenames: renames).generate(logger: Logger.root);
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
          member: RegExp(r',\n\s+\w*[Mm]axValue\(2147483647\);'),
          fromValueCase: RegExp(r'\n\s+2147483647 => \w*[Mm]axValue,'),
        ),
      ],
    );
  } on Object catch (e, s) {
    stderr.writeln('Failed to extract enums: $e\n$s');
    exit(1);
  }

  try {
    generateWasmExports(
      generator: _createGenerator(
        enumMemberRenames: renames,
        compilerOpts: ['-D__wasm__'],
      ),
      outputPath: _wasmOutput,
      typeName: 'GhosttyExports',
    );
  } on Object catch (e, s) {
    stderr.writeln('Failed to generate WASM exports: $e\n$s');
    exit(1);
  }
}

Map<String, Map<String, String>> _extractEnumMemberRenames() {
  final generator = FfiGenerator(
    output: Output(dartFile: Uri.file(_nativeOutput)),
    headers: _headers(),
    enums: const Enums(include: _includeType),
  );

  final library = ffigen.parse(Context(Logger.root, generator));
  final renames = <String, Map<String, String>>{};

  for (final binding in library.bindings) {
    if (binding is! EnumClass) continue;

    final members = [
      for (final c in binding.enumConstants) c.originalName ?? c.name,
    ];
    final prefix = longestCommonPrefix(members);

    renames[binding.originalName] = {
      for (final m in members)
        m: toCamelCase(
          prefix.isNotEmpty && m.startsWith(prefix)
              ? m.substring(prefix.length)
              : m,
        ),
    };
  }

  return renames;
}

Headers _headers({List<String> compilerOpts = const []}) => Headers(
  entryPoints: [Uri.file('../../ghostty/include/ghostty/vt.h')],
  include: (header) {
    final path = header.path;
    return path.contains('ghostty/vt.h') || path.contains('ghostty/vt/');
  },
  compilerOptions: [
    ...defaultCompilerOpts(Logger.root),
    ..._compilerOpts,
    ...compilerOpts,
  ],
);

const _nonLeafFunctions = {
  'ghostty_terminal_resize',
  'ghostty_terminal_vt_write',
  'ghostty_terminal_set',
};

FfiGenerator _createGenerator({
  Map<String, Map<String, String>>? enumMemberRenames,
  List<String> compilerOpts = const [],
}) => FfiGenerator(
  output: Output(
    dartFile: Uri.file(_nativeOutput),
    preamble: '// ignore_for_file: unused_field',
    style: const NativeExternalBindings(
      assetId: 'package:libghostty/libghostty.dart',
    ),
  ),
  headers: _headers(compilerOpts: compilerOpts),
  functions: Functions(
    include: (d) => d.originalName.startsWith('ghostty_'),
    isLeaf: (d) => !_nonLeafFunctions.contains(d.originalName),
  ),
  unions: const Unions(include: _includeType, rename: _stripPrefix),
  structs: const Structs(include: _includeType, rename: _stripPrefix),
  typedefs: const Typedefs(include: _includeType, rename: _stripPrefix),
  enums: Enums(
    include: _includeType,
    rename: _stripPrefix,
    renameMember: enumMemberRenames != null
        ? Declarations.renameMemberWithMap(enumMemberRenames)
        : (d, m) => m,
  ),
);

bool _includeType(Declaration d) => d.originalName.startsWith('Ghostty');

String _stripPrefix(Declaration d) =>
    d.originalName.replaceFirst('Ghostty', '');

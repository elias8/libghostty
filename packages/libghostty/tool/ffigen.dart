/// Generates FFI bindings and WASM typed exports from ghostty-vt headers.
///
/// Usage:
///   cd packages/libghostty
///   dart run tool/ffigen.dart [ghostty-source-directory]
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

late final String _includePath;
String get _headerPath => '$_includePath/ghostty/vt.h';

// Functions outside this allowlist use non-leaf calls. The key, cell, row,
// iterator, and SGR functions below have bounded work without allocation,
// logging, callbacks, or Dart VM APIs in the pinned C implementation.
const _leafFunctions = {
  // Key accessors are bounded. Action/key setters use closed enum wrappers;
  // exposing raw integer arguments would require auditing their logging paths.
  'ghostty_key_event_get_action',
  'ghostty_key_event_get_key',
  'ghostty_key_event_get_mods',
  'ghostty_key_event_get_consumed_mods',
  'ghostty_key_event_get_composing',
  'ghostty_key_event_get_utf8',
  'ghostty_key_event_get_unshifted_codepoint',
  'ghostty_key_event_set_mods',
  'ghostty_key_event_set_consumed_mods',
  'ghostty_key_event_set_composing',
  'ghostty_key_event_set_utf8',
  'ghostty_key_event_set_unshifted_codepoint',
  'ghostty_key_encoder_setopt_from_terminal',
  'ghostty_key_event_set_action',
  'ghostty_key_event_set_key',
  'ghostty_cell_get',
  'ghostty_row_get',
  'ghostty_render_state_row_iterator_next',
  'ghostty_render_state_row_cells_next',
  'ghostty_render_state_row_cells_select',
  'ghostty_sgr_reset',
  'ghostty_sgr_attribute_tag',
  'ghostty_sgr_attribute_value',
  'ghostty_sgr_unknown_full',
  'ghostty_sgr_unknown_partial',
  'ghostty_osc_command_data',
  'ghostty_osc_command_type',
  'ghostty_osc_end',
  'ghostty_osc_free',
  'ghostty_osc_new',
  'ghostty_osc_next',
  'ghostty_osc_reset',
  'ghostty_osc_set',
  'ghostty_formatter_format_buf',
  'ghostty_terminal_selection_format_buf',
};

Future<void> main(List<String> arguments) async {
  if (arguments.length > 1) {
    stderr.writeln(
      'Usage: dart run tool/ffigen.dart [ghostty-source-directory]',
    );
    exitCode = 64;
    return;
  }
  final source = Directory(arguments.singleOrNull ?? '../../ghostty').absolute;
  _includePath = '${source.path}/include';
  Logger.root.onRecord.listen((r) => stderr.writeln(r));

  if (!File(_headerPath).existsSync()) {
    stderr.writeln(
      'Missing ffigen entry-point header: $_headerPath. '
      'Run this command from packages/libghostty and pass the Ghostty source directory, or place it at ../../ghostty.',
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

  final format = await Process.run(Platform.resolvedExecutable, [
    'format',
    '--language-version=3.11',
    _nativeOutput,
    _enumsOutput,
    _wasmOutput,
  ]);
  stdout.write(format.stdout);
  if (format.exitCode != 0) {
    stderr.write(format.stderr);
    exit(format.exitCode);
  }
}

FfiGenerator _createGenerator({
  List<String> compilerOpts = const [],
}) => FfiGenerator(
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
        declaration.isLeaf = _leafFunctions.contains(declaration.originalName);
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
        declaration.isIncluded = _includeType(declaration) ? .ifUsed : .never;
        declaration.name = _stripPrefix(declaration);
      },
      enumClass: (declaration) {
        declaration.isIncluded = _includeType(declaration);
        declaration.name = _stripPrefix(declaration);
        if (!declaration.isIncluded) return;
        final members = [
          for (final constant in declaration.constants) constant.originalName,
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

Input _headers({List<String> compilerOpts = const []}) => Input(
  entryPoints: [Uri.file(_headerPath)],
  include: (header) {
    final path = header.path;
    return path.contains('ghostty/vt.h') || path.contains('ghostty/vt/');
  },
  compilerOptions: ['-I$_includePath', ...compilerOpts],
  appendCompilerOptions: true,
);

bool _includeType(NamedNode d) => d.originalName.startsWith('Ghostty');

String _stripPrefix(NamedNode d) => d.originalName.replaceFirst('Ghostty', '');

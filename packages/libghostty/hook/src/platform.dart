import 'package:code_assets/code_assets.dart';

/// Returns the dynamic library file extension for [os].
String libraryExtension(OS os) => switch (os) {
  OS.macOS || OS.iOS => 'dylib',
  OS.windows => 'dll',
  _ => 'so',
};

/// Maps [OS] and [Architecture] to a platform key for binary naming.
String platformKey(OS os, Architecture arch) {
  final osStr = switch (os) {
    OS.macOS => 'macos',
    OS.linux => 'linux',
    OS.windows => 'windows',
    OS.iOS => 'ios',
    OS.android => 'android',
    _ => throw Exception(
      'No pre-built binaries available for $os. '
      'Install Zig to compile from source.',
    ),
  };
  final archStr = switch (arch) {
    Architecture.x64 => 'x64',
    Architecture.arm64 => 'arm64',
    Architecture.arm => 'arm',
    Architecture.ia32 => 'ia32',
    _ => throw Exception(
      'No pre-built binaries available for $arch. '
      'Install Zig to compile from source.',
    ),
  };
  return '$osStr-$archStr';
}

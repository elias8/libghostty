import 'package:code_assets/code_assets.dart';

/// Maps Dart [OS], [Architecture], and optional [IOSSdk] to a Zig target
/// triple string for cross-compilation.
///
/// Returns `null` when targeting the current host (no cross-compilation
/// needed).
String? zigTarget(OS targetOS, Architecture targetArch, {IOSSdk? iOSSdk}) {
  if (targetOS == OS.current && targetArch == Architecture.current) return null;

  final archStr = switch (targetArch) {
    Architecture.x64 => 'x86_64',
    Architecture.arm64 => 'aarch64',
    Architecture.arm => 'arm',
    Architecture.ia32 => 'x86',
    _ => throw ArgumentError('Unsupported architecture: $targetArch'),
  };

  final osStr = switch (targetOS) {
    OS.macOS => 'macos',
    OS.linux => 'linux',
    OS.windows => 'windows',
    OS.iOS => iOSSdk == IOSSdk.iPhoneSimulator ? 'ios-simulator' : 'ios',
    OS.android => 'linux-android',
    _ => throw ArgumentError('Unsupported OS: $targetOS'),
  };

  return '$archStr-$osStr';
}

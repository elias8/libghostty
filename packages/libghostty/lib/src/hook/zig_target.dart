import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

String? zigTarget(OS targetOS, Architecture targetArch, {IOSSdk? iOSSdk}) {
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
    OS.android => switch (targetArch) {
      Architecture.arm64 => 'linux-android',
      Architecture.x64 => 'linux-android',
      Architecture.arm => 'linux-androideabi',
      _ => throw ArgumentError('Unsupported Android architecture: $targetArch'),
    },
    _ => throw ArgumentError('Unsupported OS: $targetOS'),
  };

  return '$archStr-$osStr';
}

extension BuildInputZigTarget on BuildInput {
  String? targetTriple() {
    final os = config.code.targetOS;
    final arch = config.code.targetArchitecture;
    final iOSSdk = os == OS.iOS ? config.code.iOS.targetSdk : null;
    return zigTarget(os, arch, iOSSdk: iOSSdk);
  }
}

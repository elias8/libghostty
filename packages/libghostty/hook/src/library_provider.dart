import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:crypto/crypto.dart';
import 'package:hooks/hooks.dart';

import 'asset_hashes.dart';
import 'ghostty_source.dart';
import 'platform.dart';
import 'zig_target.dart';

part 'compile_from_source.dart';
part 'download_prebuilt.dart';
part 'prebuilt_local.dart';

/// Strategy for acquiring the native library binary.
sealed class LibraryProvider {
  const LibraryProvider();

  /// Acquires the native library and writes it to [target].
  Future<void> provide(File target);

  /// Selects the best strategy for the current environment.
  ///
  /// Priority:
  /// 1. [PrebuiltLocal] — [PrebuiltLocal.envKey] env var points to a binary
  /// 2. [CompileFromSource] — Zig is installed and source is locally available
  /// 3. [DownloadPrebuilt] — download from GitHub Release
  static LibraryProvider resolve(BuildInput input) {
    final prebuiltPath = Platform.environment[PrebuiltLocal.envKey];
    if (prebuiltPath != null) return PrebuiltLocal(prebuiltPath);

    if (zigAvailable() && sourceAvailable(input.packageRoot)) {
      return CompileFromSource(input);
    }

    return DownloadPrebuilt(
      targetOS: input.config.code.targetOS,
      targetArch: input.config.code.targetArchitecture,
      cacheBase: input.outputDirectoryShared,
      packageRoot: input.packageRoot,
    );
  }

  /// Returns `true` if Ghostty source is locally available via
  /// [ghosttySrcEnvKey] or a `ghostty/` directory at the workspace root.
  static bool sourceAvailable(Uri packageRoot) {
    final envPath = Platform.environment[ghosttySrcEnvKey];
    if (envPath != null && envPath.isNotEmpty) {
      if (Directory(envPath).existsSync()) return true;
    }

    final workspaceRoot = packageRoot.resolve('../../');
    final localGhostty = Directory.fromUri(workspaceRoot.resolve('ghostty/'));
    return localGhostty.existsSync();
  }

  /// Checks if Zig is installed and available on PATH.
  static bool zigAvailable() {
    try {
      final result = Process.runSync('zig', ['version']);
      return result.exitCode == 0;
    } on ProcessException {
      return false;
    }
  }
}

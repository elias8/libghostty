import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Environment variable that overrides source resolution with a local checkout.
const ghosttySrcEnvKey = 'GHOSTTY_SRC';

const _defaultTarballBase = 'https://github.com/ghostty-org/ghostty/archive';

Future<void> applyPatches(Directory sourceDir, Uri packageRoot) async {
  final patchDir = Directory.fromUri(packageRoot.resolve('patches/'));
  if (!patchDir.existsSync()) return;

  final patches =
      patchDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.patch'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  for (final patch in patches) {
    final result = Process.runSync('patch', [
      '-p1',
      '-d',
      sourceDir.path,
      '-i',
      patch.path,
    ]);
    if (result.exitCode != 0) {
      sourceDir.deleteSync(recursive: true);
      throw Exception(
        'Failed to apply patch ${patch.uri.pathSegments.last}:\n'
        '${result.stderr}\n'
        'The upstream Ghostty source may have changed. Rebase the fork '
        'and regenerate patches.',
      );
    }
  }
}

/// Downloads a source tarball, extracts it, applies patches, and caches
/// the result.
///
/// Uses [tarballUrl] if provided, otherwise builds URL from the pinned commit
/// in `ghostty.version`. Applies patches from `patches/` after extraction.
/// Patch content is hashed into the cache key.
Future<Directory> downloadSource(
  Uri cacheBase, {
  required Uri packageRoot,
  String? tarballUrl,
}) async {
  final commit = pinnedCommit(packageRoot);
  final patchHash = _patchesHash(packageRoot);
  final cacheKey = '${commit.substring(0, 12)}-$patchHash';
  final cacheDir = Directory.fromUri(
    cacheBase.resolve('ghostty-source-$cacheKey/'),
  );
  if (cacheDir.existsSync()) return cacheDir;

  tarballUrl ??= '$_defaultTarballBase/$commit.tar.gz';

  final tarball = File.fromUri(cacheBase.resolve('$commit.tar.gz'));
  tarball.parent.createSync(recursive: true);

  final httpClient = HttpClient();
  try {
    final request = await httpClient.getUrl(Uri.parse(tarballUrl));
    final response = await request.close();
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to download Ghostty source: HTTP ${response.statusCode}. '
        'Check your network connection or set '
        '$ghosttySrcEnvKey to a local checkout.',
      );
    }
    final sink = tarball.openWrite();
    await response.pipe(sink);
  } finally {
    httpClient.close();
  }

  cacheDir.createSync(recursive: true);
  final extractResult = Process.runSync('tar', [
    'xzf',
    tarball.path,
    '-C',
    cacheDir.path,
    '--strip-components=1',
  ]);
  if (extractResult.exitCode != 0) {
    cacheDir.deleteSync(recursive: true);
    throw Exception(
      'Failed to extract Ghostty source: ${extractResult.stderr}',
    );
  }

  tarball.deleteSync();

  await applyPatches(cacheDir, packageRoot);

  return cacheDir;
}

/// Reads the pinned Ghostty commit from `ghostty.version` at [packageRoot].
String pinnedCommit(Uri packageRoot) {
  final file = File.fromUri(packageRoot.resolve('ghostty.version'));
  if (!file.existsSync()) {
    throw StateError(
      'ghostty.version not found at ${file.path}. '
      'This file must contain the pinned Ghostty commit hash.',
    );
  }
  return file.readAsStringSync().trim();
}

/// Resolves the Ghostty source directory.
///
/// Resolution order:
/// 1. [ghosttySrcEnvKey] environment variable
/// 2. Local `ghostty/` directory at the workspace root
/// 3. Download from GitHub (cached in [cacheBase])
///
/// Options 1 and 2 are used as-is. Option 3 downloads upstream source and
/// applies patches from the `patches/` directory.
Future<Directory> resolveSource({
  required Uri packageRoot,
  required Uri cacheBase,
}) async {
  final envPath = Platform.environment[ghosttySrcEnvKey];
  if (envPath != null && envPath.isNotEmpty) {
    final dir = Directory(envPath);
    if (dir.existsSync()) return dir;
  }

  final workspaceRoot = packageRoot.resolve('../../');
  final localGhostty = Directory.fromUri(workspaceRoot.resolve('ghostty/'));
  if (localGhostty.existsSync()) return localGhostty;

  return downloadSource(cacheBase, packageRoot: packageRoot);
}

String _patchesHash(Uri packageRoot) {
  final patchDir = Directory.fromUri(packageRoot.resolve('patches/'));
  if (!patchDir.existsSync()) return 'none';

  final patches =
      patchDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.patch'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  if (patches.isEmpty) return 'none';

  final bytes = BytesBuilder();
  for (final patch in patches) {
    bytes.add(patch.readAsBytesSync());
  }
  return sha256.convert(bytes.toBytes()).toString().substring(0, 8);
}

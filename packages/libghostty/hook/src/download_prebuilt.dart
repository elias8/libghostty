part of 'library_provider.dart';

/// Downloads a pre-built binary from GitHub Releases.
final class DownloadPrebuilt extends LibraryProvider {
  static const _defaultBaseUrl =
      'https://github.com/elias8/libghostty/releases/download';

  final OS targetOS;
  final Uri cacheBase;
  final Uri packageRoot;
  final String baseUrl;
  final Architecture targetArch;
  final Map<String, String> hashes;

  const DownloadPrebuilt({
    required this.targetOS,
    required this.cacheBase,
    required this.packageRoot,
    required this.targetArch,
    Map<String, String>? hashes,
    this.baseUrl = _defaultBaseUrl,
  }) : hashes = hashes ?? assetHashes;

  @override
  Future<void> provide(File target) async {
    final commit = pinnedCommit(packageRoot);
    final commitShort = commit.substring(0, 7);
    final platform = platformKey(targetOS, targetArch);
    final ext = libraryExtension(targetOS);
    final fileName = 'libghostty-vt-$commitShort-$platform.$ext';
    final hashKey = '$commitShort-$platform';

    final cacheDir = Directory.fromUri(
      cacheBase.resolve('prebuilt-$commitShort/'),
    );
    final cachedFile = File('${cacheDir.path}/$fileName');

    if (cachedFile.existsSync()) {
      if (!_validateHash(cachedFile, hashKey)) {
        cachedFile.deleteSync();
      }
    }

    if (!cachedFile.existsSync()) {
      await _download(commit, fileName, cachedFile);
      if (!_validateHash(cachedFile, hashKey)) {
        cachedFile.deleteSync();
        throw Exception(
          'SHA256 hash mismatch for downloaded $fileName. '
          'The file may be corrupted. Try again, or file an issue at '
          'https://github.com/elias8/libghostty/issues',
        );
      }
    }

    target.parent.createSync(recursive: true);
    cachedFile.copySync(target.path);
  }

  Future<void> _download(
    String commit,
    String fileName,
    File destination,
  ) async {
    final url = '$baseUrl/v$commit/$fileName';

    destination.parent.createSync(recursive: true);
    final tmp = File('${destination.path}.tmp');

    final httpClient = HttpClient();
    try {
      final request = await httpClient.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != 200) {
        throw Exception(
          'Failed to download pre-built library from $url '
          '(HTTP ${response.statusCode}).\n'
          'Options:\n'
          '  - Install Zig and rebuild from source\n'
          '  - Set ${PrebuiltLocal.envKey} to a local binary path\n'
          '  - Check https://github.com/elias8/libghostty/releases',
        );
      }
      final sink = tmp.openWrite();
      await response.pipe(sink);
    } finally {
      httpClient.close();
    }

    tmp.renameSync(destination.path);
  }

  bool _validateHash(File file, String hashKey) {
    final expectedHash = hashes[hashKey];
    if (expectedHash == null) return true;

    final bytes = file.readAsBytesSync();
    final digest = sha256.convert(bytes).toString();
    return digest == expectedHash;
  }
}

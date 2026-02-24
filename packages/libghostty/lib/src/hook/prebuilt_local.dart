part of 'library_provider.dart';

/// Uses a pre-built binary from a local file path.
final class PrebuiltLocal extends LibraryProvider {
  /// Environment variable that overrides library resolution with a local path.
  static const envKey = 'LIBGHOSTTY_PREBUILT';

  final String path;

  const PrebuiltLocal(this.path);

  @override
  Future<void> provide(File target) async {
    final source = File(path);
    if (!source.existsSync()) {
      throw Exception('$envKey set to $path but file does not exist.');
    }
    target.parent.createSync(recursive: true);
    source.copySync(target.path);
  }
}

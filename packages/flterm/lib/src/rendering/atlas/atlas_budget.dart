/// Aggregate admission accounting for one compatible atlas configuration.
///
/// Image bytes describe projected RGBA payload, not native heap residency.
final class AtlasBudget {
  static const defaultImageBytes = 4 * 1024 * 1024;
  static const defaultIndexEntries = 4096;
  static const defaultKeyBytes = 256 * 1024;

  final int maxImageBytes;
  final int maxIndexEntries;
  final int maxKeyBytes;
  var _imageBytes = 0;
  var _indexEntries = 0;
  var _keyBytes = 0;

  int get imageBytes => _imageBytes;
  int get indexEntries => _indexEntries;
  int get keyBytes => _keyBytes;

  bool resizeImage(int previous, int next) {
    final total = _imageBytes + next - previous;
    if (total > maxImageBytes) return false;
    _imageBytes = total;
    return true;
  }

  void releaseImage(int bytes) => _imageBytes -= bytes;

  void clearIndexes() {
    _indexEntries = 0;
    _keyBytes = 0;
  }

  AtlasBudget({
    this.maxImageBytes = defaultImageBytes,
    this.maxIndexEntries = defaultIndexEntries,
    this.maxKeyBytes = defaultKeyBytes,
  });

  bool canIndex(int entries, int bytes) =>
      indexEntries + entries <= maxIndexEntries &&
      keyBytes + bytes <= maxKeyBytes;

  void addIndex(int entries, int bytes) {
    assert(
      canIndex(entries, bytes),
      'Positive index admission must be reserved.',
    );
    _indexEntries += entries;
    _keyBytes += bytes;
  }
}

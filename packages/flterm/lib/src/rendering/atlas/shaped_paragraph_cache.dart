import 'dart:ui' show Paragraph;

typedef _ParagraphKey = (String, int, bool, bool);

final class _ParagraphEntry {
  final _ParagraphKey key;
  final Paragraph paragraph;
  var borrowers = 0;

  _ParagraphEntry(this.key, this.paragraph);
}

final class ShapedParagraphLease {
  final ShapedParagraphCache _cache;
  _ParagraphEntry? _entry;

  ShapedParagraphLease._(this._cache, this._entry);

  Paragraph get paragraph => _entry!.paragraph;

  void release() {
    final entry = _entry;
    if (entry == null) return;
    _entry = null;
    _cache._release(entry);
  }
}

/// Retains shaped paragraphs for one atlas's font configuration and generation.
/// Borrowed paragraphs survive disposal until their last row releases them.
final class ShapedParagraphCache {
  static const _maxIdleEntries = 128;
  static const _maxIdleCodeUnits = 32768;
  final _entries = <_ParagraphKey, _ParagraphEntry>{};
  final _idle = <_ParagraphKey, _ParagraphEntry>{};
  var _idleCodeUnits = 0;
  var _disposed = false;

  ShapedParagraphLease acquire(
    String text, {
    required int foreground,
    required bool bold,
    required bool italic,
    required Paragraph Function() create,
  }) {
    if (_disposed) throw StateError('ShapedParagraphCache is disposed');
    final key = (text, foreground, bold, italic);
    final entry = _entries[key] ??= _ParagraphEntry(key, create());
    if (_idle.remove(key) != null) _idleCodeUnits -= text.length;
    entry.borrowers++;
    return ShapedParagraphLease._(this, entry);
  }

  void _release(_ParagraphEntry entry) {
    entry.borrowers--;
    if (entry.borrowers != 0) return;
    if (!identical(_entries[entry.key], entry)) {
      entry.paragraph.dispose();
      return;
    }
    _idle[entry.key] = entry;
    _idleCodeUnits += entry.key.$1.length;
    while (_idle.length > _maxIdleEntries ||
        _idleCodeUnits > _maxIdleCodeUnits) {
      final key = _idle.keys.first;
      final evicted = _idle.remove(key)!;
      _idleCodeUnits -= key.$1.length;
      _entries.remove(key);
      evicted.paragraph.dispose();
    }
  }

  void dispose() {
    _disposed = true;
    for (final entry in _idle.values) {
      entry.paragraph.dispose();
    }
    _idle.clear();
    _entries.clear();
    _idleCodeUnits = 0;
  }
}

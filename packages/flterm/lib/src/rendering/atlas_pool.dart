import 'package:flutter/foundation.dart' show Listenable;
import 'package:flutter/painting.dart' show PaintingBinding;

import 'atlas/atlas.dart';

typedef _AtlasKey = ({AtlasConfig config, int fontGeneration});

/// Keeps a shared [Atlas] alive until [release] is called.
class AtlasLease {
  final AtlasPool _owner;
  final _AtlasKey _key;
  final _CachedAtlas _entry;
  var _released = false;

  AtlasLease._(this._owner, this._key, this._entry);

  Atlas get atlas => _entry.atlas;

  AtlasConfig get config => _key.config;

  bool get isCurrent => _key.fontGeneration == _owner._fontGeneration;

  /// Releases this lease.
  ///
  /// Repeated calls have no effect.
  void release() {
    if (_released) return;
    _released = true;
    _owner._releaseAtlas(_key, _entry);
  }
}

/// Owns render resources that can be shared by compatible terminal views.
///
/// Render boxes derive an [AtlasConfig] from their current
/// theme/metrics/DPR and share it within the current font generation.
///
/// This type is internal; public sharing is exposed through `TerminalScope`.
class AtlasPool {
  final _atlases = <_AtlasKey, _CachedAtlas>{};
  Listenable? _systemFonts;
  var _fontGeneration = 0;

  /// Acquires the atlas for [config], creating it when necessary.
  ///
  /// The caller must release the returned lease when it no longer uses the
  /// atlas.
  AtlasLease acquireAtlas(AtlasConfig config) {
    final systemFonts = _atlases.isEmpty
        ? PaintingBinding.instance.systemFonts
        : null;
    final key = (config: config, fontGeneration: _fontGeneration);
    final entry = _atlases.putIfAbsent(key, () => _CachedAtlas(Atlas(config)));
    if (systemFonts != null) {
      systemFonts.addListener(_onSystemFontsChanged);
      _systemFonts = systemFonts;
    }
    entry.references++;
    return AtlasLease._(this, key, entry);
  }

  /// Disposes every pooled atlas, including atlases with outstanding leases.
  void dispose() {
    for (final entry in _atlases.values) {
      entry.atlas.dispose();
    }
    _atlases.clear();
    _stopListening();
    _fontGeneration++;
  }

  void _onSystemFontsChanged() => _fontGeneration++;

  void _stopListening() {
    _systemFonts?.removeListener(_onSystemFontsChanged);
    _systemFonts = null;
  }

  void _releaseAtlas(_AtlasKey key, _CachedAtlas releasedEntry) {
    final entry = _atlases[key];
    if (entry == null) return;
    if (!identical(entry, releasedEntry)) return;

    entry.references--;
    if (entry.references > 0) return;

    _atlases.remove(key);
    entry.atlas.dispose();
    if (_atlases.isEmpty) _stopListening();
  }
}

class _CachedAtlas {
  final Atlas atlas;
  var references = 0;

  _CachedAtlas(this.atlas);
}

import 'dart:convert' show utf8;

import 'package:crypto/crypto.dart' show sha256;
import 'package:flterm/src/foundation/cell_metrics.dart';
import 'package:flterm/src/foundation/terminal_render_observer.dart';
import 'package:flterm/src/foundation/terminal_theme.dart';
import 'package:flterm/src/rendering/atlas/atlas_config.dart';
import 'package:flterm/src/rendering/terminal_render_cache.dart';
import 'package:flterm/src/rendering/terminal_renderer.dart';
import 'package:flutter/rendering.dart' show ViewportOffset;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:libghostty/libghostty.dart' show Terminal;

import '../protocol.dart';

const _metrics = CellMetrics(cellWidth: 8, cellHeight: 16, baseline: 12);

/// Logical size of the benchmark grid at device pixel ratio 1.
final benchmarkSurfaceSize = Size(
  benchmarkColumns * _metrics.cellWidth,
  benchmarkRows * _metrics.cellHeight,
);
final _theme = TerminalTheme.dark().copyWith(
  fontFamilyFallback: const ['Noto Sans JP', 'Noto Emoji'],
);
final _atlasConfig = AtlasConfig.fromTheme(
  theme: _theme,
  metrics: _metrics,
  devicePixelRatio: 1,
);
Future<String>? _loadingFonts;

/// Loads every bundled font before rendering and returns their identity.
Future<String> loadBenchmarkFonts() => _loadingFonts ??= _loadFonts();

Future<String> _loadFonts() async {
  final assets = await Future.wait([
    rootBundle.load('assets/fonts/JetBrainsMono-Regular.ttf'),
    rootBundle.load('assets/fonts/JetBrainsMono-Bold.ttf'),
    rootBundle.load('assets/fonts/NotoSansJP-Regular.ttf'),
    rootBundle.load('assets/fonts/NotoEmoji-Regular.ttf'),
  ]);
  final textLoader = FontLoader('Noto Sans JP')
    ..addFont(Future.value(assets[2]));
  final emojiLoader = FontLoader('Noto Emoji')
    ..addFont(Future.value(assets[3]));
  await Future.wait([textLoader.load(), emojiLoader.load()]);

  return benchmarkFontDigest(
    jetBrainsMonoRegular: assets[0],
    jetBrainsMonoBold: assets[1],
    notoSansJp: assets[2],
    notoEmoji: assets[3],
  );
}

/// Identifies every bundled font that can affect benchmark rendering.
String benchmarkFontDigest({
  required ByteData jetBrainsMonoRegular,
  required ByteData jetBrainsMonoBold,
  required ByteData notoSansJp,
  required ByteData notoEmoji,
}) {
  final componentDigests = [
    sha256.convert(Uint8List.sublistView(jetBrainsMonoRegular)),
    sha256.convert(Uint8List.sublistView(jetBrainsMonoBold)),
    sha256.convert(Uint8List.sublistView(notoSansJp)),
    sha256.convert(Uint8List.sublistView(notoEmoji)),
  ].join(':');
  return 'sha256:${sha256.convert(utf8.encode(componentDigests))}';
}

/// Fixed terminal surface shared by every rendering workload.
final class BenchmarkTerminalSurface extends StatelessWidget {
  final Terminal terminal;
  final TerminalRenderCache cache;

  const BenchmarkTerminalSurface({
    super.key,
    required this.terminal,
    required this.cache,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: .ltr,
      child: Align(
        alignment: .topLeft,
        child: SizedBox(
          width: benchmarkSurfaceSize.width,
          height: benchmarkSurfaceSize.height,
          child: TerminalRenderer(
            terminal: terminal,
            theme: _theme,
            metrics: _metrics,
            offset: ViewportOffset.zero(),
            renderObserver: const _FocusedRenderObserver(),
            renderCache: cache,
          ),
        ),
      ),
    );
  }
}

/// Keeps an already-populated atlas alive after its renderer is detached.
TerminalAtlasHandle retainBenchmarkAtlas(TerminalRenderCache cache) {
  return cache.acquireAtlas(_atlasConfig);
}

final class _FocusedRenderObserver implements TerminalRenderObserver {
  const _FocusedRenderObserver();

  @override
  bool get hasFocus => true;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:flterm/src/controller/terminal_controller.dart';
import 'package:flterm/src/foundation.dart';
import 'package:flterm/src/rendering/atlas/atlas.dart';
import 'package:flterm/src/rendering/terminal_renderer.dart';
import 'package:flterm/src/view/terminal_scope.dart';
import 'package:flterm/src/view/terminal_view.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Atlas acquireAndRelease(TerminalRenderer renderer) {
  final lease = renderer.atlasPool.acquireAtlas(
    AtlasConfig.fromTheme(
      theme: renderer.theme,
      metrics: renderer.metrics,
      devicePixelRatio: renderer.devicePixelRatio,
    ),
  );
  final atlas = lease.atlas;
  lease.release();
  return atlas;
}

void main() {
  late TerminalController first;
  late TerminalController second;
  const secondBoundary = ValueKey('second-boundary');

  setUp(() {
    first = TerminalController();
    second = TerminalController();
    for (final controller in [first, second]) {
      controller.write(Uint8List.fromList(utf8.encode('\x1b[?25lABC=>')));
    }
  });

  tearDown(() {
    first.dispose();
    second.dispose();
  });

  Widget host({
    bool showFirst = true,
    bool explicitFirst = false,
    TerminalTheme? secondTheme,
  }) {
    Widget firstView = TerminalView(
      key: const ValueKey('first'),
      controller: first,
      padding: EdgeInsets.zero,
    );
    if (explicitFirst) firstView = TerminalScope(child: firstView);
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            SizedBox(height: 100, child: showFirst ? firstView : null),
            SizedBox(
              height: 100,
              child: RepaintBoundary(
                key: secondBoundary,
                child: TerminalView(
                  key: const ValueKey('second'),
                  controller: second,
                  theme: secondTheme,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<int>> secondPixels(WidgetTester tester) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(secondBoundary),
    );
    return (await tester.runAsync(() async {
      final image = await boundary.toImage();
      try {
        final bytes = await image.toByteData();
        return bytes!.buffer.asUint8List().toList();
      } finally {
        image.dispose();
      }
    }))!;
  }

  testWidgets('implicit siblings share and last unmount releases the atlas', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pump();
    final renderers = tester
        .widgetList<TerminalRenderer>(find.byType(TerminalRenderer))
        .toList();
    expect(renderers, hasLength(2));
    final atlas = acquireAndRelease(renderers[0]);
    expect(acquireAndRelease(renderers[1]), same(atlas));
    atlas.addCodepoint(0x41, bold: false, italic: false);
    atlas.ensureImage();
    expect(atlas.textImage, isNotNull);
    final before = await secondPixels(tester);

    await tester.pumpWidget(host(showFirst: false));
    await tester.pump();
    expect(atlas.textImage, isNotNull);
    expect(await secondPixels(tester), orderedEquals(before));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(atlas.textImage, isNull);

    await tester.pumpWidget(host());
    await tester.pump();
    final later = tester.widget<TerminalRenderer>(
      find.byType(TerminalRenderer).first,
    );
    expect(acquireAndRelease(later), isNot(same(atlas)));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('explicit scope stays separate from automatic siblings', (
    tester,
  ) async {
    await tester.pumpWidget(host(explicitFirst: true));
    await tester.pump();
    final renderers = tester
        .widgetList<TerminalRenderer>(find.byType(TerminalRenderer))
        .toList();
    final scoped = acquireAndRelease(renderers[0]);
    final fallback = acquireAndRelease(renderers[1]);
    expect(scoped, isNot(same(fallback)));
    await tester.pumpWidget(host(showFirst: false));
    await tester.pump();
    expect(
      acquireAndRelease(
        tester.widget<TerminalRenderer>(find.byType(TerminalRenderer)),
      ),
      same(fallback),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    expect(fallback.textImage, isNull);
  });

  testWidgets('font and DPR changes partition automatic atlas resources', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(secondTheme: TerminalTheme.dark().copyWith(fontSize: 20)),
    );
    await tester.pump();
    final renderers = tester
        .widgetList<TerminalRenderer>(find.byType(TerminalRenderer))
        .toList();
    expect(
      acquireAndRelease(renderers[0]),
      isNot(same(acquireAndRelease(renderers[1]))),
    );
    final firstAtlas = acquireAndRelease(renderers[0]);
    final config = AtlasConfig.fromTheme(
      theme: renderers[0].theme,
      metrics: renderers[0].metrics,
      devicePixelRatio: renderers[0].devicePixelRatio,
    );
    final otherDpr = renderers[0].atlasPool.acquireAtlas(
      config.copyWith(devicePixelRatio: config.devicePixelRatio + 1),
    );
    expect(otherDpr.atlas, isNot(same(firstAtlas)));
    otherDpr.release();
    await tester.pumpWidget(const SizedBox.shrink());
    expect(firstAtlas.textImage, isNull);
  });
}

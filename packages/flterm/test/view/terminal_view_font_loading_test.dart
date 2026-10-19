@Tags(['ffi'])
library;

import 'dart:io';

import 'package:flterm/flterm.dart';
import 'package:flterm/src/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final suppliedBytes in [false, true]) {
    testWidgets('remeasures after primary font loading, bytes=$suppliedBytes', (
      tester,
    ) async {
      final bytes = await tester.runAsync(
        () =>
            File('test/fixtures/fonts/JetBrainsMono-Regular.ttf').readAsBytes(),
      );
      expect(bytes, isNotNull);
      final fontData = suppliedBytes ? bytes : null;
      final family = 'TerminalViewLatePrimary${suppliedBytes ? 'Raw' : 'Auto'}';
      final theme = TerminalTheme.dark().copyWith(
        fontFamily: family,
        fontFamilyFallback: const ['Ahem'],
        fontSize: 20,
      );
      final controller = TerminalController();
      addTearDown(controller.dispose);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: TerminalView(
            controller: controller,
            theme: theme,
            fontData: fontData,
          ),
        ),
      );
      final before = tester
          .widget<TerminalRenderer>(find.byType(TerminalRenderer))
          .metrics;
      final loader = FontLoader(family)
        ..addFont(Future.value(ByteData.sublistView(bytes!)));
      await tester.runAsync(loader.load);
      await tester.pump();
      await tester.pump();
      final expected = measureCellMetrics(
        fontSize: theme.fontSize,
        fontFamily: family,
        fontWeight: theme.fontWeight,
        fontFamilyFallback: theme.fontFamilyFallback,
        fontData: fontData,
      );
      expect(
        expected.cellWidth,
        isNot(before.cellWidth),
        reason: 'The actual loaded primary face must replace Ahem geometry.',
      );
      expect(
        tester.widget<TerminalRenderer>(find.byType(TerminalRenderer)).metrics,
        expected,
        reason: 'The visible view must publish the loaded font metrics.',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

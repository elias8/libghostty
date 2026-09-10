@Tags(['ffi'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flterm/src/foundation.dart';
import 'package:flterm/src/links/link_interaction.dart';
import 'package:flterm/src/links/link_settings.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart' show Mods, Position, Terminal;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LinkInteraction', () {
    const metrics = CellMetrics(cellWidth: 8, cellHeight: 16, baseline: 12);

    late Terminal terminal;
    late LinkInteraction interaction;

    LinkContext context() {
      return LinkContext(terminal: terminal, rows: 4, cols: 80, cwd: null);
    }

    void updateLinks({
      LinkSettings settings = const LinkSettings(),
      HyperlinkStyle idleStyle = const HyperlinkStyle(),
    }) {
      interaction.update(
        context: context(),
        settings: settings,
        idleStyle: idleStyle,
      );
    }

    setUp(() {
      terminal = Terminal(cols: 80, rows: 4);
      interaction = LinkInteraction();
      updateLinks();
    });

    tearDown(() {
      interaction.dispose();
      terminal.dispose();
    });

    void write(String text) {
      terminal.write(Uint8List.fromList(utf8.encode(text)));
      interaction.invalidateContent();
    }

    group('handleHover', () {
      test('returns a range when activation is allowed', () {
        write('https://example.test');
        updateLinks(
          settings: LinkSettings(modifier: .none, onActivate: (_) {}),
        );

        final result = interaction.handleHover(
          localPosition: const Offset(8, 0),
          metrics: metrics,
          virtualMods: const Mods.none(),
        );

        expect(
          result,
          const CellRange(
            start: Position(row: 0, col: 0),
            end: Position(row: 0, col: 19),
          ),
        );
      });

      test('returns null when activation is unavailable', () {
        write('https://example.test');

        final result = interaction.handleHover(
          localPosition: const Offset(8, 0),
          metrics: metrics,
          virtualMods: const Mods.none(),
        );

        expect(result, isNull);
      });
    });

    group('handlePress', () {
      test('stores a candidate for release', () {
        write('https://example.test');
        updateLinks(
          settings: LinkSettings(modifier: .none, onActivate: (_) {}),
        );

        final result = interaction.handlePress(
          localPosition: const Offset(8, 0),
          metrics: metrics,
          pointerKind: PointerDeviceKind.mouse,
          virtualMods: const Mods.none(),
        );

        expect(result, isTrue);
      });

      test('returns false when no link is present', () {
        write('plain text');
        updateLinks(
          settings: LinkSettings(modifier: .none, onActivate: (_) {}),
        );

        final result = interaction.handlePress(
          localPosition: const Offset(8, 0),
          metrics: metrics,
          pointerKind: PointerDeviceKind.mouse,
          virtualMods: const Mods.none(),
        );

        expect(result, isFalse);
      });
    });

    group('handleRelease', () {
      test('returns the press candidate on the same cell', () {
        write('https://example.test');
        updateLinks(
          settings: LinkSettings(modifier: .none, onActivate: (_) {}),
        );
        interaction.handlePress(
          localPosition: const Offset(8, 0),
          metrics: metrics,
          pointerKind: PointerDeviceKind.mouse,
          virtualMods: const Mods.none(),
        );

        final result = interaction.handleRelease(
          localPosition: const Offset(8, 0),
          metrics: metrics,
        );

        expect(result?.text, 'https://example.test');
      });

      test('returns null on a different cell', () {
        write('https://example.test');
        updateLinks(
          settings: LinkSettings(modifier: .none, onActivate: (_) {}),
        );
        interaction.handlePress(
          localPosition: const Offset(8, 0),
          metrics: metrics,
          pointerKind: PointerDeviceKind.mouse,
          virtualMods: const Mods.none(),
        );

        final result = interaction.handleRelease(
          localPosition: const Offset(24, 0),
          metrics: metrics,
        );

        expect(result, isNull);
      });
    });

    group('invalidateContent', () {
      test('cancels activation of a pressed link', () {
        write('https://example.test');
        updateLinks(
          settings: LinkSettings(modifier: .none, onActivate: (_) {}),
        );
        interaction.handlePress(
          localPosition: const Offset(8, 0),
          metrics: metrics,
          pointerKind: .mouse,
          virtualMods: const .none(),
        );

        interaction.invalidateContent();

        expect(
          interaction.handleRelease(
            localPosition: const Offset(8, 0),
            metrics: metrics,
          ),
          isNull,
        );
      });

      test('refreshes stationary hover after content changes', () {
        write('https://example.test');
        updateLinks(
          settings: LinkSettings(modifier: .none, onActivate: (_) {}),
        );
        interaction.handleHover(
          localPosition: const Offset(8, 0),
          metrics: metrics,
          virtualMods: const Mods.none(),
        );
        var notifications = 0;
        interaction.addListener(() => notifications++);

        terminal.write(Uint8List.fromList(utf8.encode('\r\x1b[2Kplain text')));
        interaction.invalidateContent();

        expect(interaction.highlighted, isNull);
        expect(notifications, 0);
      });
    });

    group('snapshot', () {
      test('returns highlight-only state without idle styling', () {
        write('https://example.test');
        updateLinks(
          settings: LinkSettings(modifier: .none, onActivate: (_) {}),
        );
        interaction.handleHover(
          localPosition: const Offset(8, 0),
          metrics: metrics,
          virtualMods: const Mods.none(),
        );

        final result = interaction.snapshot();

        expect(result.matches, isEmpty);
      });

      test('includes idle links when idle styling is visible', () {
        write('https://a.test https://b.test');
        updateLinks(
          settings: LinkSettings(modifier: .none, onActivate: (_) {}),
          idleStyle: const HyperlinkStyle(underline: .single),
        );

        final result = interaction.snapshot();

        expect(result.contains(const Position(row: 0, col: 20)), isTrue);
      });

      test('keeps cached snapshot when only callback identity changes', () {
        write('https://example.test');
        updateLinks(
          settings: LinkSettings(modifier: .none, onActivate: (_) {}),
          idleStyle: const HyperlinkStyle(underline: .single),
        );
        final first = interaction.snapshot();

        updateLinks(
          settings: LinkSettings(modifier: .none, onActivate: (_) {}),
          idleStyle: const HyperlinkStyle(underline: .single),
        );
        final second = interaction.snapshot();

        expect(identical(first, second), isTrue);
      });

      test('reuses idle matches when hover changes', () {
        write('https://a.test https://b.test');
        updateLinks(
          settings: LinkSettings(modifier: .none, onActivate: (_) {}),
          idleStyle: const HyperlinkStyle(underline: .single),
        );
        final first = interaction.snapshot();

        interaction.handleHover(
          localPosition: const Offset(8, 0),
          metrics: metrics,
          virtualMods: const Mods.none(),
        );
        final second = interaction.snapshot();

        expect(identical(first.matches, second.matches), isTrue);
      });
    });
  });
}

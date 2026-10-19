@Tags(['ffi'])
library;

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flterm/src/foundation/cell_metrics.dart';
import 'package:flterm/src/foundation/cell_range.dart';
import 'package:flterm/src/foundation/dynamic_color.dart';
import 'package:flterm/src/foundation/terminal_theme.dart';
import 'package:flterm/src/links/link_match.dart';
import 'package:flterm/src/links/link_settings.dart'
    show ActivatedLink, LinkType;
import 'package:flterm/src/links/link_snapshot.dart';
import 'package:flterm/src/rendering/atlas/atlas.dart';
import 'package:flterm/src/rendering/atlas/sprite_buffer.dart';
import 'package:flterm/src/rendering/frame_builder.dart';
import 'package:flterm/src/rendering/paint_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart';

void main() {
  group('FrameBuilder', () {
    const metrics = CellMetrics(cellWidth: 8, cellHeight: 16, baseline: 12);

    AtlasConfig config() {
      return AtlasConfig(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        fontFamily: 'monospace',
        fontFamilyFallback: const [],
        metrics: metrics,
        devicePixelRatio: 1.0,
      );
    }

    void writeUtf8(Terminal terminal, String text) {
      terminal.write(Uint8List.fromList(utf8.encode(text)));
    }

    List<double> xPositions(AtlasSprites sprites) {
      final transforms = sprites.sealedTransforms;
      return List.generate(sprites.count, (index) => transforms[index * 4 + 2]);
    }

    List<double> yPositions(AtlasSprites sprites) {
      final transforms = sprites.sealedTransforms;
      return List.generate(sprites.count, (index) => transforms[index * 4 + 3]);
    }

    String entryRectKey(AtlasEntry entry) {
      return [
        entry.srcLeft,
        entry.srcTop,
        entry.srcRight,
        entry.srcBottom,
      ].join(',');
    }

    String spriteRectKey(AtlasSprites sprites, int index) {
      final rects = sprites.sealedRects;
      final offset = index * 4;
      return [
        rects[offset],
        rects[offset + 1],
        rects[offset + 2],
        rects[offset + 3],
      ].join(',');
    }

    List<String> wideGlyphs(
      Atlas atlas,
      AtlasSprites sprites,
      Iterable<String> glyphs,
    ) {
      final glyphByRect = <String, String>{};
      for (final glyph in glyphs) {
        final entry =
            atlas.addCodepoint(
                  glyph.runes.single,
                  bold: false,
                  italic: false,
                  span: 2,
                )
                as AtlasEntry;
        glyphByRect[entryRectKey(entry)] = glyph;
      }
      return [
        for (var i = 0; i < sprites.count; i++)
          glyphByRect[spriteRectKey(sprites, i)]!,
      ];
    }

    ({
      Terminal terminal,
      Atlas atlas,
      SpriteBuffer sprites,
      PaintState state,
      FrameBuilder builder,
    })
    createFrame({required int cols, required int rows}) {
      final terminal = Terminal(cols: cols, rows: rows);
      final atlas = Atlas(config());
      final sprites = SpriteBuffer();
      final state = PaintState(TerminalTheme.dark(), metrics)
        ..cols = cols
        ..rows = rows;
      final builder = FrameBuilder(atlas, sprites, state)
        ..configure(rows, cols);
      addTearDown(() {
        builder.dispose();
        sprites.dispose();
        atlas.dispose();
        terminal.dispose();
      });
      return (
        terminal: terminal,
        atlas: atlas,
        sprites: sprites,
        state: state,
        builder: builder,
      );
    }

    late Terminal terminal;
    late Atlas atlas;
    late SpriteBuffer sprites;
    late PaintState state;
    late FrameBuilder builder;

    setUp(() {
      terminal = Terminal(cols: 8, rows: 2);
      atlas = Atlas(config());
      sprites = SpriteBuffer();
      state = PaintState(TerminalTheme.dark(), metrics)
        ..cols = 8
        ..rows = 2;
      builder = FrameBuilder(atlas, sprites, state)..configure(2, 8);
    });

    tearDown(() {
      builder.dispose();
      sprites.dispose();
      atlas.dispose();
      terminal.dispose();
    });

    test('sync preserves rows when viewport identities move and return', () {
      writeUtf8(
        terminal,
        '\x1b[38;2;1;2;3mA\r\n\x1b[38;2;4;5;6mB\r\n\x1b[38;2;7;8;9mC',
      );
      builder.sync(terminal, terminalDirty: true);
      expect(sprites.regular.sealedColors, [
        0xFF040506.toSigned(32),
        0xFF070809.toSigned(32),
      ]);
      terminal.scrollViewport(-1);
      builder.sync(terminal, terminalDirty: true);
      expect(sprites.regular.sealedColors, [
        0xFF010203.toSigned(32),
        0xFF040506.toSigned(32),
      ]);
      terminal.scrollToBottom();
      builder.sync(terminal, terminalDirty: true);
      expect(sprites.regular.sealedColors, [
        0xFF040506.toSigned(32),
        0xFF070809.toSigned(32),
      ]);
    });

    test('sync preserves RGB and palette erase backgrounds', () async {
      terminal.palette = [
        for (var i = 0; i < 256; i++)
          if (i == 1) const RgbColor(4, 5, 6) else const RgbColor(0, 0, 0),
      ];
      writeUtf8(
        terminal,
        '\x1b[48;2;1;2;3m\x1b[2K\x1b[2;1H\x1b[41m\x1b[2K\x1b[0m',
      );
      builder.sync(terminal, terminalDirty: true);
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      for (final vertices in sprites.background.buildVertices(
        Uint16List.fromList([0, 1, 2, 0, 2, 3, 4, 5, 6, 4, 6, 7]),
      )) {
        canvas.drawVertices(vertices, BlendMode.src, Paint());
      }
      final picture = recorder.endRecording();
      final image = picture.toImageSync(64, 32);
      final pixels = (await image.toByteData())!;
      expect(pixels.getUint32(0), 0x010203FF);
      expect(pixels.getUint32(16 * 64 * 4), 0x040506FF);
      image.dispose();
      picture.dispose();
    });

    test('sync preserves page-local style colors across a tall viewport', () {
      final frame = createFrame(cols: 300, rows: 400);
      final input = StringBuffer();
      for (var row = 0; row < 400; row++) {
        input.write('\x1b[${row + 1};1H\x1b[38;2;${row % 256};2;3mA');
      }
      writeUtf8(frame.terminal, input.toString());
      expect(frame.terminal.memoryUsage.primaryPages, greaterThan(1));
      final snapshot = RenderState();
      final rows = RowIterator();
      final cells = CellIterator();
      final colorsById = <int, int>{};
      var hasPageLocalCollision = false;
      try {
        snapshot.update(frame.terminal);
        rows.reset(snapshot);
        while (rows.next()) {
          cells.reset(rows);
          expect(cells.next(), isTrue);
          final id = cells.styleId;
          final color = (cells.style.foreground as RgbColor).toArgb32;
          final previous = colorsById[id];
          if (id > 0 && id < 1024 && previous != null && previous != color) {
            hasPageLocalCollision = true;
          }
          colorsById[id] = color;
        }
      } finally {
        cells.dispose();
        rows.dispose();
        snapshot.dispose();
      }
      expect(hasPageLocalCollision, isTrue);
      frame.builder.sync(frame.terminal, terminalDirty: true);
      expect(frame.sprites.regular.sealedColors, [
        for (var row = 0; row < 400; row++)
          (0xFF000203 | ((row % 256) << 16)).toSigned(32),
      ]);
    });

    test('sync replaces grapheme and wide content with plain text', () {
      writeUtf8(terminal, 'e\u0301\u4e2d');
      builder.sync(terminal, terminalDirty: true);
      expect(sprites.regular.count, 1);
      expect(
        spriteRectKey(sprites.regular, 0),
        entryRectKey(
          atlas.add((text: 'e\u0301', bold: false, italic: false))
              as AtlasEntry,
        ),
      );
      writeUtf8(terminal, '\r\x1b[2KAB');
      builder.sync(terminal, terminalDirty: true);
      expect(sprites.regular.count, 2);
      expect(sprites.wide.count, 0);
      expect(sprites.emoji.count, 0);
      expect(xPositions(sprites.regular), [0, 8]);
      builder.markRowsDirty(0, 1);
      builder.sync(terminal, terminalDirty: false);
      expect(sprites.regular.count, 2);
      expect(xPositions(sprites.regular), [0, 8]);
    });

    test('sync emits text, sprite, and emoji channels', () {
      writeUtf8(terminal, 'A\u2500\u{1F600}');

      builder.sync(terminal, terminalDirty: true);

      expect(sprites.regular.count, greaterThan(0));
      expect(sprites.sprite.count, greaterThan(0));
      expect(sprites.emoji.count, greaterThan(0));
      expect(atlas.spriteImage, isNotNull);
      expect(atlas.emojiImage, isNotNull);
    });

    test('sync lets a private-use symbol occupy a following blank cell', () {
      writeUtf8(terminal, '\u{E5FF} A');

      builder.sync(terminal, terminalDirty: true);

      expect(
        (sprites.regular.count, sprites.wide.count, sprites.emoji.count),
        (1, 1, 0),
      );
    });

    test('sync constrains a private-use symbol before text to one cell', () {
      writeUtf8(terminal, '\u{E5FF}A');

      builder.sync(terminal, terminalDirty: true);

      expect(sprites.regular.count, 2);
      expect(sprites.wide.count, 0);
    });

    test('sync constrains consecutive private-use symbols to one cell', () {
      writeUtf8(terminal, '\u{E5FF}\u{E5FF} ');

      builder.sync(terminal, terminalDirty: true);

      expect(sprites.regular.count, 2);
      expect(sprites.wide.count, 0);
    });

    test('sync lets a symbol borrow after an invisible symbol', () {
      writeUtf8(terminal, '\x1b[8m\u{E5FF}\x1b[28m\u{E5FF} ');

      builder.sync(terminal, terminalDirty: true);

      expect(sprites.wide.count, 1);
    });

    test('sync lets a symbol borrow after a preedit replacement', () {
      writeUtf8(terminal, '\u{E5FF}\u{E5FF} \x1b[1;1H');

      builder.sync(terminal, terminalDirty: true, preeditText: 'a');

      expect(sprites.wide.count, 1);
    });

    test('sync constrains a final-column private-use symbol to one cell', () {
      final frame = createFrame(cols: 1, rows: 1);
      writeUtf8(frame.terminal, '\u{E5FF}');

      frame.builder.sync(frame.terminal, terminalDirty: true);

      expect(frame.sprites.regular.count, 1);
      expect(frame.sprites.wide.count, 0);
    });

    test(
      'sync does not expand a private-use symbol over nonbreaking space',
      () {
        writeUtf8(terminal, '\u{E5FF}\u00A0');

        builder.sync(terminal, terminalDirty: true);

        expect(sprites.wide.count, 0);
      },
    );

    test('sync rebuilds external and terminal dirty rows together', () {
      writeUtf8(terminal, 'A\r\nB');
      builder.sync(terminal, terminalDirty: true);
      builder.markRowsDirty(1, 2);
      writeUtf8(terminal, '\x1b[1;1HC');

      builder.sync(terminal, terminalDirty: true);

      expect(sprites.regular.count, 2);
    });

    test('sync emits operator ligatures without adding text atlas entries', () {
      final initialCacheSize = atlas.cacheSize;
      writeUtf8(terminal, '\x1b[?25l=> != ==');

      builder.sync(terminal, terminalDirty: true);

      expect(sprites.shaped.count, 3);
      expect(
        sprites.shaped.rows.where((row) => row.isNotEmpty).single,
        hasLength(3),
      );
      expect(atlas.cacheSize, initialCacheSize);
    });

    test('shared operator paragraphs survive replacing one visible row', () {
      writeUtf8(terminal, '\x1b[?25l=>\r\n=>');
      builder.sync(terminal, terminalDirty: true);
      final untouched = sprites.shaped.rows[1].single;
      expect(
        sprites.shaped.rows[0].single.paragraph,
        same(untouched.paragraph),
      );
      builder.markRowsDirty(0, 1);
      builder.sync(terminal, terminalDirty: false);
      expect(sprites.shaped.rows[1].single, same(untouched));
      writeUtf8(terminal, '\x1b[1;1H!=');
      builder.sync(terminal, terminalDirty: true);
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawParagraph(untouched.paragraph, untouched.offset);
      final picture = recorder.endRecording();
      picture.dispose();
      expect(
        sprites.shaped.rows[1].single.paragraph,
        same(untouched.paragraph),
      );
      expect(untouched.clip, const Rect.fromLTWH(0, 16, 16, 16));
      expect(
        sprites.shaped.rows[0].single.clip,
        const Rect.fromLTWH(0, 0, 16, 16),
      );
      builder.markRowsDirty(0, 1);
      writeUtf8(terminal, '\x1b[1;1H=>');
      builder.sync(terminal, terminalDirty: true);
      expect(
        sprites.shaped.rows[0].single.paragraph,
        same(untouched.paragraph),
      );
    });

    test('sync separates operator runs at a foreground color boundary', () {
      writeUtf8(terminal, '=>\x1b[31m!=');

      builder.sync(terminal, terminalDirty: true);

      expect(
        sprites.shaped.rows.where((row) => row.isNotEmpty).single,
        hasLength(2),
      );
    });

    test('sync chunks long operator runs without adding atlas entries', () {
      final localTerminal = Terminal(cols: 260, rows: 1);
      final localAtlas = Atlas(config());
      final localSprites = SpriteBuffer();
      final localState = PaintState(TerminalTheme.dark(), metrics)
        ..cols = 260
        ..rows = 1;
      final localBuilder = FrameBuilder(localAtlas, localSprites, localState)
        ..configure(1, 260);
      addTearDown(() {
        localBuilder.dispose();
        localSprites.dispose();
        localAtlas.dispose();
        localTerminal.dispose();
      });
      final initialCacheSize = localAtlas.cacheSize;
      writeUtf8(localTerminal, '\x1b[?25l${List.filled(260, r'$').join()}');

      localBuilder.sync(localTerminal, terminalDirty: true);

      expect(localSprites.shaped.count, 2);
      expect(localAtlas.cacheSize, initialCacheSize);
    });

    test('sync resolves palette colors from render state colors', () {
      terminal.palette = [
        for (var i = 0; i < 256; i++)
          if (i == 1) const RgbColor(1, 2, 3) else const RgbColor(0, 0, 0),
      ];
      writeUtf8(terminal, '\x1b[31mA');

      builder.sync(terminal, terminalDirty: true);

      expect(sprites.regular.sealedColors.single, 0xFF010203.toSigned(32));
    });

    test('sync updates terminal background after OSC 11', () {
      terminal.foreground = const RgbColor(255, 255, 255);
      terminal.background = const RgbColor(0, 0, 0);
      builder.sync(terminal, terminalDirty: true);
      writeUtf8(terminal, '\x1b]11;rgb:1e/20/24\x1b\\');

      builder.sync(terminal, terminalDirty: true);

      expect(state.terminalBackgroundArgb, 0xFF1E2024);
    });

    test('sync rebuilds retained text colors after OSC 10', () {
      terminal.foreground = const RgbColor(255, 255, 255);
      terminal.background = const RgbColor(0, 0, 0);
      writeUtf8(terminal, 'A\r\nB');
      builder.sync(terminal, terminalDirty: true);
      writeUtf8(terminal, '\x1b]10;rgb:01/02/03\x1b\\');

      builder.sync(terminal, terminalDirty: true);

      expect(sprites.regular.sealedColors, [
        0xFF010203.toSigned(32),
        0xFF010203.toSigned(32),
      ]);
    });

    test('sync emits erase backgrounds after resize', () {
      final frame = createFrame(cols: 8, rows: 2);
      writeUtf8(frame.terminal, '\x1b[2;2H\x1b[48;2;30;32;36m\x1b[K\x1b[0m');
      frame.builder.sync(frame.terminal, terminalDirty: true);
      frame.terminal.resize(cols: 10, rows: 2);
      frame.state
        ..cols = 10
        ..rows = 2;
      frame.builder
        ..configure(2, 10)
        ..markAllRowsDirty();

      frame.builder.sync(frame.terminal, terminalDirty: true);

      expect(frame.sprites.background.count, greaterThan(0));
    });

    test('sync resolves cursor dynamic colors from render state colors', () {
      state.updateTheme(
        TerminalTheme.dark().copyWith(
          cursor: const CursorTheme(color: DynamicColor.cellForeground()),
        ),
      );
      terminal.palette = [
        for (var i = 0; i < 256; i++)
          if (i == 1) const RgbColor(1, 2, 3) else const RgbColor(0, 0, 0),
      ];
      writeUtf8(terminal, '\x1b[31mA\x1b[1;1H');

      builder.sync(terminal, terminalDirty: true);

      expect(state.cursorColorArgb, 0xFF010203);
    });

    test('sync resolves underline colors from render state colors', () {
      terminal.palette = [
        for (var i = 0; i < 256; i++)
          if (i == 1) const RgbColor(1, 2, 3) else const RgbColor(0, 0, 0),
      ];
      writeUtf8(terminal, '\x1b[4;58;5;1mA');

      builder.sync(terminal, terminalDirty: true);

      expect(sprites.underline.sealedColors.single, 0xFF010203.toSigned(32));
    });

    test('sync preserves link underline across a highlight boundary', () {
      final singleUnderline = atlas.addDecoration(.single) as AtlasEntry;
      state.updateTheme(
        TerminalTheme.dark().copyWith(
          hyperlink: const HyperlinkTheme(
            idle: HyperlinkStyle(underline: .single),
          ),
        ),
      );
      writeUtf8(terminal, 'ab');
      terminal.selection = Selection.fromRefs(
        start: GridRef.at(terminal, const Position(row: 0, col: 1)),
        end: GridRef.at(terminal, const Position(row: 0, col: 1)),
      );
      const link = LinkMatch(
        priority: 0,
        sourceOrder: 0,
        hoverOnly: false,
        link: ActivatedLink(
          type: LinkType.custom,
          id: 'test',
          text: 'ab',
          range: CellRange(
            start: Position(row: 0, col: 0),
            end: Position(row: 0, col: 1),
          ),
        ),
      );

      builder.sync(
        terminal,
        terminalDirty: true,
        linkSnapshot: const LinkSnapshot([link]),
      );

      expect(sprites.underline.count, 2);
      expect(
        spriteRectKey(sprites.underline, 0),
        entryRectKey(singleUnderline),
      );
      expect(
        spriteRectKey(sprites.underline, 1),
        entryRectKey(singleUnderline),
      );
    });

    test(
      'sync emits selection background without terminal access in paint',
      () {
        writeUtf8(terminal, 'hello');
        terminal.selection = Selection.fromRefs(
          start: GridRef.at(terminal, const Position(row: 0, col: 1)),
          end: GridRef.at(terminal, const Position(row: 0, col: 2)),
        );

        builder.sync(terminal, terminalDirty: true);

        expect(sprites.background.count, greaterThan(0));
      },
    );

    test('sync emits search match colors', () {
      final search = Search(terminal);
      addTearDown(search.dispose);
      state.updateTheme(
        TerminalTheme.dark().copyWith(
          search: const SearchTheme(
            match: SelectionTheme(
              background: DynamicColor.fixed(Color(0xFF112233)),
              foreground: DynamicColor.fixed(Color(0xFF445566)),
            ),
          ),
        ),
      );
      writeUtf8(terminal, 'hello');
      search.setNeedle('ell');
      search.run();

      builder.sync(
        terminal,
        terminalDirty: true,
        searchDirty: true,
        searchMatches: search.viewportMatches,
      );

      expect(sprites.background.count, greaterThan(0));
      expect(sprites.regular.sealedColors, contains(0xFF445566.toSigned(32)));
    });

    test('sync highlights the visible part of a multiline search match', () {
      final frame = createFrame(cols: 5, rows: 2);
      final search = Search(frame.terminal);
      addTearDown(search.dispose);
      frame.state.updateTheme(
        TerminalTheme.dark().copyWith(
          search: const SearchTheme(
            match: SelectionTheme(
              foreground: DynamicColor.fixed(Color(0xFF445566)),
            ),
          ),
        ),
      );
      writeUtf8(frame.terminal, 'abcdef\r\n11111\r\n22222\r\n33333');
      search.setNeedle('abcdef');
      search.run();
      frame.terminal.scrollToRow(1);
      search.run();

      frame.builder.sync(
        frame.terminal,
        terminalDirty: true,
        searchDirty: true,
        searchMatches: search.viewportMatches,
      );

      expect(
        frame.sprites.regular.sealedColors,
        contains(0xFF445566.toSigned(32)),
      );
    });

    test('sync applies highlight precedence', () {
      final search = Search(terminal);
      addTearDown(search.dispose);
      state.updateTheme(
        TerminalTheme.dark().copyWith(
          selection: const SelectionTheme(
            foreground: DynamicColor.fixed(Color(0xFF0000FF)),
          ),
          search: const SearchTheme(
            match: SelectionTheme(
              foreground: DynamicColor.fixed(Color(0xFFFF0000)),
            ),
            selectedMatch: SelectionTheme(
              foreground: DynamicColor.fixed(Color(0xFF00FF00)),
            ),
          ),
        ),
      );
      writeUtf8(terminal, 'hello');
      terminal.selection = Selection.fromRefs(
        start: GridRef.at(terminal, const Position(row: 0, col: 1)),
        end: GridRef.at(terminal, const Position(row: 0, col: 3)),
      );
      search.setNeedle('ell');
      search.run();

      builder.sync(
        terminal,
        terminalDirty: true,
        searchDirty: true,
        searchMatches: search.viewportMatches,
      );
      final ordinaryColors = sprites.regular.sealedColors.toList();
      search.selectNext();
      builder.sync(
        terminal,
        terminalDirty: true,
        searchDirty: true,
        searchMatches: search.viewportMatches,
        selectedSearchMatch: search.selectedMatch,
      );

      expect(ordinaryColors, contains(0xFF0000FF.toSigned(32)));
      expect(ordinaryColors, isNot(contains(0xFFFF0000.toSigned(32))));
      expect(sprites.regular.sealedColors, contains(0xFF00FF00.toSigned(32)));
    });

    test('sync restores rows when search matches are cleared', () {
      state.updateTheme(
        TerminalTheme.dark().copyWith(
          search: const SearchTheme(
            match: SelectionTheme(
              foreground: DynamicColor.fixed(Color(0xFFFF0000)),
            ),
          ),
        ),
      );
      writeUtf8(terminal, 'AB\r\nCD');
      builder.sync(terminal, terminalDirty: true);
      final normalColors = sprites.regular.sealedColors.toList();
      final match = Selection.fromRefs(
        start: GridRef.at(terminal, const Position(row: 0, col: 0)),
        end: GridRef.at(terminal, const Position(row: 0, col: 1)),
      );

      builder.sync(
        terminal,
        terminalDirty: false,
        searchDirty: true,
        searchMatches: [match],
      );
      builder.sync(terminal, terminalDirty: false, searchDirty: true);

      expect(sprites.regular.sealedColors, normalColors);
    });

    test('sync resets hidden style state at a default row', () {
      final frame = createFrame(cols: 1, rows: 2);
      writeUtf8(frame.terminal, '\x1b[8;31mA\x1b[0m\r\nB');

      frame.builder.sync(frame.terminal, terminalDirty: true);

      expect(frame.sprites.regular.sealedColors, [
        frame.state.terminalForegroundArgb.toSigned(32),
      ]);
      expect(yPositions(frame.sprites.regular), [16.0]);
    });

    test('sync resolves block cursor glyph from cached frame state', () {
      writeUtf8(terminal, 'A\x1b[1;1H');
      builder.sync(terminal, terminalDirty: true);

      expect(state.cursor.visible, isTrue);
      expect(state.cursor.viewportX, 0);
      expect(state.cursorGlyph, isNotNull);
    });

    test(
      'direct cursor refresh replaces ink and disposal clears borrowed state',
      () {
        const largeMetrics = CellMetrics(
          cellWidth: 1100,
          cellHeight: 1100,
          baseline: 850,
        );
        final largeAtlas = Atlas(
          AtlasConfig(
            fontSize: 800,
            fontWeight: FontWeight.normal,
            fontFamily: 'monospace',
            fontFamilyFallback: const [],
            metrics: largeMetrics,
            devicePixelRatio: 1,
          ),
        );
        final localTerminal = Terminal(cols: 2, rows: 1);
        final localSprites = SpriteBuffer();
        final localState = PaintState(TerminalTheme.dark(), largeMetrics)
          ..rows = 1
          ..cols = 2;
        final localBuilder = FrameBuilder(largeAtlas, localSprites, localState)
          ..configure(1, 2);
        try {
          writeUtf8(localTerminal, 'A\x1b[H');
          localBuilder.sync(localTerminal, terminalDirty: true);
          final first = localState.cursorGlyph;
          expect(first, isA<DirectGlyph>());
          expect(largeAtlas.cacheSize, 0);
          localBuilder.refreshCursorGlyph();
          expect(localState.cursorGlyph, isA<DirectGlyph>());
          expect(localState.cursorGlyph, isNot(same(first)));
          localState.cursorFocused = false;
          localBuilder.refreshCursorGlyph();
          expect(localState.cursorGlyph, isNull);
          localState.cursorFocused = true;
          localBuilder.refreshCursorGlyph();
          expect(localState.cursorGlyph, isA<DirectGlyph>());
          writeUtf8(localTerminal, '\r\x1b[5mA\x1b[H');
          localBuilder.sync(localTerminal, terminalDirty: true);
          localState.blinkVisible = false;
          localBuilder.refreshCursorGlyph();
          expect(localState.cursorGlyph, isNull);
          localState.blinkVisible = true;
          localBuilder.refreshCursorGlyph();
          expect(localState.cursorGlyph, isA<DirectGlyph>());
          writeUtf8(localTerminal, '\x1b[6 q');
          localBuilder.sync(localTerminal, terminalDirty: true);
          expect(localState.cursorGlyph, isNull);
          localBuilder.dispose();
          expect(localState.cursorGlyph, isNull);
        } finally {
          localSprites.dispose();
          largeAtlas.dispose();
          localTerminal.dispose();
        }
      },
    );

    test('sync skips cursor glyph on empty cells', () {
      builder.sync(terminal, terminalDirty: true);

      expect(state.cursor.visible, isTrue);
      expect(state.cursorGlyph, isNull);
    });

    test('sync skips cursor glyph when the terminal is unfocused', () {
      state.cursorFocused = false;
      writeUtf8(terminal, 'A\x1b[1;1H');

      builder.sync(terminal, terminalDirty: true);

      expect(state.cursor.visible, isTrue);
      expect(state.cursorGlyph, isNull);
    });

    test('sync skips cursor glyph for non-block cursors', () {
      state.updateTheme(
        TerminalTheme.dark().copyWith(
          cursor: const CursorTheme(shape: CursorShape.underline),
        ),
      );
      writeUtf8(terminal, 'A\x1b[1;1H');

      builder.sync(terminal, terminalDirty: true);

      expect(state.cursor.visible, isTrue);
      expect(state.cursor.visualStyle, CursorShape.underline);
      expect(state.cursorGlyph, isNull);
    });

    test('sync skips cursor glyph on invisible text', () {
      writeUtf8(terminal, '\x1b[8mA\x1b[1;1H');

      builder.sync(terminal, terminalDirty: true);

      expect(state.cursor.visible, isTrue);
      expect(state.cursorGlyph, isNull);
    });

    test('sync skips cursor glyph on blink-hidden text', () {
      state.blinkVisible = false;
      writeUtf8(terminal, '\x1b[5mA\x1b[1;1H');

      builder.sync(terminal, terminalDirty: true);

      expect(state.cursor.visible, isTrue);
      expect(state.cursorGlyph, isNull);
    });

    test('sync replaces only the active preedit cell range', () {
      writeUtf8(terminal, 'abcdef\x1b[1;3H');

      builder.sync(terminal, terminalDirty: true, preeditText: '日');

      expect(xPositions(sprites.regular), [0.0, 8.0, 32.0, 40.0]);
      expect(xPositions(sprites.wide), [16.0]);
    });

    test('sync treats Unicode preedit text as grapheme clusters', () {
      const preeditClusterCases = [
        (
          description: 'ZWJ emoji preedit text as one cluster',
          text: '👩‍💻',
          regularPositions: [0.0, 8.0, 32.0, 40.0],
          emojiPositions: [16.0],
        ),
        (
          description: 'skin tone emoji preedit text as one cluster',
          text: '👍🏽',
          regularPositions: [0.0, 8.0, 32.0, 40.0],
          emojiPositions: [16.0],
        ),
        (
          description: 'combining preedit text as one narrow cluster',
          text: 'é',
          regularPositions: [0.0, 8.0, 16.0, 24.0, 32.0, 40.0],
          emojiPositions: <double>[],
        ),
        (
          description: 'variation selector preedit text as one cluster',
          text: '❤️',
          regularPositions: [0.0, 8.0, 32.0, 40.0],
          emojiPositions: [16.0],
        ),
      ];

      for (final clusterCase in preeditClusterCases) {
        final frame = createFrame(cols: 8, rows: 2);
        writeUtf8(frame.terminal, 'abcdef\x1b[1;3H');

        frame.builder.sync(
          frame.terminal,
          terminalDirty: true,
          preeditText: clusterCase.text,
        );

        expect(
          xPositions(frame.sprites.regular),
          clusterCase.regularPositions,
          reason: clusterCase.description,
        );
        expect(
          xPositions(frame.sprites.emoji),
          clusterCase.emojiPositions,
          reason: clusterCase.description,
        );
      }
    });

    test('sync emits a continuous preedit underline', () {
      writeUtf8(terminal, 'abcdef\x1b[1;3H');

      builder.sync(terminal, terminalDirty: true, preeditText: '日');

      expect(sprites.underline.count, 0);
      expect(sprites.decoration.count, 1);
    });

    test('sync shifts wide preedit left at the row edge', () {
      writeUtf8(terminal, 'abcdefgh\x1b[1;8H');

      builder.sync(terminal, terminalDirty: true, preeditText: '日');

      expect(xPositions(sprites.wide), [48.0]);
      expect(sprites.decoration.count, 1);
    });

    test('sync keeps visible tail when preedit is wider than the row', () {
      final frame = createFrame(cols: 6, rows: 1);
      writeUtf8(frame.terminal, 'ab\x1b[1;3H');

      frame.builder.sync(
        frame.terminal,
        terminalDirty: true,
        preeditText: '一二三四五',
      );

      expect(xPositions(frame.sprites.wide), [0.0, 16.0, 32.0]);
      expect(
        wideGlyphs(frame.atlas, frame.sprites.wide, ['一', '二', '三', '四', '五']),
        ['三', '四', '五'],
      );
    });

    test('sync keeps the visible tail when clipping starts at column zero', () {
      final frame = createFrame(cols: 4, rows: 1);

      frame.builder.sync(
        frame.terminal,
        terminalDirty: true,
        preeditText: '一二三四五',
      );

      expect(xPositions(frame.sprites.wide), [0.0, 16.0]);
      expect(
        wideGlyphs(frame.atlas, frame.sprites.wide, ['一', '二', '三', '四', '五']),
        ['四', '五'],
      );
    });

    test('sync preserves cells after a partial wide preedit slot', () {
      final frame = createFrame(cols: 7, rows: 1);
      writeUtf8(frame.terminal, 'abcdefg\x1b[1;1H');

      frame.builder.sync(
        frame.terminal,
        terminalDirty: true,
        preeditText: '一二三四',
      );

      expect(xPositions(frame.sprites.regular), [48.0]);
      expect(xPositions(frame.sprites.wide), [0.0, 16.0, 32.0]);
    });

    test('sync suppresses wide cell that overlaps preedit range', () {
      final frame = createFrame(cols: 5, rows: 1);
      writeUtf8(frame.terminal, 'ab日x\x1b[1;5H');

      frame.builder.sync(frame.terminal, terminalDirty: true, preeditText: '你');

      expect(xPositions(frame.sprites.wide), [24.0]);
    });

    test('sync clears preedit when text becomes empty', () {
      writeUtf8(terminal, 'abcdef\x1b[1;3H');
      builder.sync(terminal, terminalDirty: true, preeditText: '日');

      builder.sync(terminal, terminalDirty: false);

      expect(state.preeditActive, isFalse);
      expect(xPositions(sprites.regular), [0.0, 8.0, 16.0, 24.0, 32.0, 40.0]);
    });

    test('sync moves unchanged preedit text with the cursor', () {
      writeUtf8(terminal, 'A\r\nB\x1b[1;1H');
      builder.sync(terminal, terminalDirty: true, preeditText: '日');
      writeUtf8(terminal, '\x1b[2;1H');

      builder.sync(terminal, terminalDirty: true, preeditText: '日');

      expect(xPositions(sprites.regular), [0.0]);
      expect(yPositions(sprites.regular), [0.0]);
      expect(xPositions(sprites.wide), [0.0]);
      expect(yPositions(sprites.wide), [16.0]);
    });

    group('incremental invalidation', () {
      test('blink changes retain rows without blinking cells', () {
        writeUtf8(terminal, '\x1b[5m=>\x1b[0m\r\n!=');
        builder.sync(terminal, terminalDirty: true);
        final retainedRun = sprites.shaped.rows[1].single;
        state.blinkVisible = false;
        builder.markBlinkRowsDirty();

        builder.sync(terminal, terminalDirty: false);

        expect(sprites.shaped.rows[1].single, same(retainedRun));
      });

      test('blink changes hide and show blinking rows', () {
        writeUtf8(terminal, '\x1b[5mA\x1b[0m\r\nB');
        builder.sync(terminal, terminalDirty: true);

        state.blinkVisible = false;
        builder.markBlinkRowsDirty();
        builder.sync(terminal, terminalDirty: false);
        expect(sprites.regular.count, 1);

        state.blinkVisible = true;
        builder.markBlinkRowsDirty();
        builder.sync(terminal, terminalDirty: false);

        expect(sprites.regular.count, 2);
      });

      test('search changes retain rows outside matches', () {
        writeUtf8(terminal, '=>\r\n!=');
        builder.sync(terminal, terminalDirty: true);
        final retainedRun = sprites.shaped.rows[1].single;
        final match = Selection.fromRefs(
          start: GridRef.at(terminal, const Position(row: 0, col: 0)),
          end: GridRef.at(terminal, const Position(row: 0, col: 1)),
        );

        builder.sync(
          terminal,
          terminalDirty: false,
          searchDirty: true,
          searchMatches: [match],
        );

        expect(sprites.shaped.rows[1].single, same(retainedRun));
      });
    });

    test('sync ignores zero-width preedit text', () {
      writeUtf8(terminal, 'abcdef\x1b[1;3H');

      builder.sync(terminal, terminalDirty: true, preeditText: '\u200B');

      expect(state.preeditActive, isFalse);
    });
  });
}

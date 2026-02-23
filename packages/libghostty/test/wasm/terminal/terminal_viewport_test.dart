@Tags(['wasm'])
library;

import 'dart:typed_data';

import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

import '../../terminal/helpers/terminal_dump.dart';
import '../helpers/setup.dart';

void main() {
  setUpAll(setUpWasm);

  group('TerminalViewport', () {
    late Terminal terminal;

    setUp(() {
      terminal = Terminal(cols: 10, rows: 3, scrollbackLimit: 100);
    });

    tearDown(() {
      terminal.dispose();
    });

    TerminalViewport createViewport({int scrollOffset = 0}) {
      return TerminalViewport(
        screen: terminal.screen,
        scrollback: terminal.scrollback,
        scrollOffset: scrollOffset,
      );
    }

    test('cellAt reads from screen when scrollOffset = 0', () {
      terminal.write(Uint8List.fromList('HELLO'.codeUnits));
      final viewport = createViewport();

      expect(viewport.cellAt(0, 0).content, 'H');
      expect(viewport.cellAt(0, 4).content, 'O');
      expect(viewport.isScrolledBack, isFalse);
    });

    test('cellAt reads from scrollback when scrollOffset > 0', () {
      terminal.write(
        Uint8List.fromList('AAA\r\nBBB\r\nCCC\r\nDDD\r\n'.codeUnits),
      );
      final scrollbackLen = terminal.scrollback.length;
      expect(scrollbackLen, greaterThan(0));

      final viewport = createViewport(scrollOffset: scrollbackLen);
      expect(
        viewport.cellAt(0, 0).content,
        terminal.scrollback.lineAt(0).cellAt(0).content,
      );
      expect(viewport.isScrolledBack, isTrue);
    });

    test('cellAt reads mix of scrollback + screen for partial scroll', () {
      terminal.write(
        Uint8List.fromList('LINE1\r\nLINE2\r\nLINE3\r\nLINE4\r\n'.codeUnits),
      );
      final scrollbackLen = terminal.scrollback.length;
      expect(scrollbackLen, greaterThanOrEqualTo(2));

      final viewport = createViewport(scrollOffset: 1);
      final firstRowAbsolute = viewport.viewportRowToAbsolute(0);
      expect(firstRowAbsolute, scrollbackLen - 1);
    });

    test('cellAt returns Cell.empty for rows before scrollback start', () {
      terminal.write(Uint8List.fromList('A\r\nB\r\n'.codeUnits));
      final scrollbackLen = terminal.scrollback.length;

      final hugeOffset = scrollbackLen + terminal.screen.rows + 10;
      final viewport = createViewport(scrollOffset: hugeOffset);
      expect(viewport.cellAt(0, 0), Cell.empty);
    });

    test(
      'cellAt handles scrollback lines shorter than current column count',
      () {
        terminal.write(
          Uint8List.fromList('AB\r\nXX\r\nYY\r\nZZ\r\n'.codeUnits),
        );
        final scrollbackLen = terminal.scrollback.length;
        expect(scrollbackLen, greaterThan(0));

        final viewport = createViewport(scrollOffset: scrollbackLen);
        expect(viewport.cellAt(0, 9), Cell.empty);
      },
    );

    test('coordinate conversion round-trips correctly', () {
      terminal.write(Uint8List.fromList('A\r\nB\r\nC\r\nD\r\n'.codeUnits));
      final viewport = createViewport(scrollOffset: 1);

      for (var vRow = 0; vRow < viewport.rows; vRow++) {
        final absRow = viewport.viewportRowToAbsolute(vRow);
        final backToViewport = viewport.absoluteRowToViewport(absRow);
        expect(backToViewport, vRow);
      }
    });

    test('isScrolledBack reflects scrollOffset state', () {
      expect(createViewport().isScrolledBack, isFalse);
      expect(createViewport(scrollOffset: 1).isScrolledBack, isTrue);
    });

    test('isAbsoluteRowVisible checks viewport bounds', () {
      terminal.write(Uint8List.fromList('A\r\nB\r\nC\r\nD\r\nE\r\n'.codeUnits));
      final scrollbackLen = terminal.scrollback.length;
      final viewport = createViewport();

      expect(viewport.isAbsoluteRowVisible(scrollbackLen), isTrue);
      expect(
        viewport.isAbsoluteRowVisible(scrollbackLen + terminal.screen.rows - 1),
        isTrue,
      );
      expect(viewport.isAbsoluteRowVisible(scrollbackLen - 1), isFalse);
    });

    test('rows and columns match screen dimensions', () {
      final viewport = createViewport();
      expect(viewport.rows, terminal.screen.rows);
      expect(viewport.cols, terminal.screen.cols);
    });

    test('lineAt returns scrollback line when scrolled', () {
      terminal.write(
        Uint8List.fromList('FIRST\r\nSECOND\r\nTHIRD\r\nFOURTH\r\n'.codeUnits),
      );
      final scrollbackLen = terminal.scrollback.length;
      expect(scrollbackLen, greaterThan(0));

      final viewport = createViewport(scrollOffset: scrollbackLen);
      final line = viewport.lineAt(0);
      expect(line.text, terminal.scrollback.lineAt(0).text);
    });

    test('lineAt returns empty line for rows before scrollback', () {
      final viewport = createViewport(scrollOffset: 100);
      final line = viewport.lineAt(0);
      expect(line.length, 0);
    });
  });

  group('resize interaction', () {
    group('viewport at scrollOffset=0 shows live screen', () {
      test('after growing rows', () {
        final t = Terminal(cols: 80, rows: 24);
        addTearDown(t.dispose);

        for (var i = 0; i < 50; i++) {
          t.write(Uint8List.fromList('Line_$i\r\n'.codeUnits));
        }

        expect(t.scrollback.length, greaterThan(0));

        t.resize(cols: 80, rows: 47);

        final viewport = TerminalViewport(
          screen: t.screen,
          scrollback: t.scrollback,
          scrollOffset: 0,
        );

        final cursorRow = t.cursor.row;
        expect(
          viewport.cellAt(cursorRow, 0),
          equals(t.screen.cellAt(cursorRow, 0)),
          reason:
              'Viewport row $cursorRow at offset 0 should '
              'match screen row $cursorRow',
        );
      });

      test('after shrinking rows', () {
        final t = Terminal(cols: 80, rows: 24);
        addTearDown(t.dispose);

        for (var i = 0; i < 50; i++) {
          t.write(Uint8List.fromList('Line_$i\r\n'.codeUnits));
        }

        t.resize(cols: 80, rows: 10);

        final viewport = TerminalViewport(
          screen: t.screen,
          scrollback: t.scrollback,
          scrollOffset: 0,
        );

        for (var row = 0; row < t.screen.rows; row++) {
          expect(
            viewport.cellAt(row, 0),
            equals(t.screen.cellAt(row, 0)),
            reason:
                'Viewport row $row at offset 0 should match screen row $row',
          );
        }
      });

      test('after shrinking then growing', () {
        final t = Terminal(cols: 80, rows: 24);
        addTearDown(t.dispose);

        for (var i = 0; i < 50; i++) {
          t.write(Uint8List.fromList('Line_$i\r\n'.codeUnits));
        }

        t.resize(cols: 80, rows: 10);
        t.resize(cols: 80, rows: 47);

        final viewport = TerminalViewport(
          screen: t.screen,
          scrollback: t.scrollback,
          scrollOffset: 0,
        );

        for (var row = 0; row < t.screen.rows; row++) {
          expect(
            viewport.cellAt(row, 0),
            equals(t.screen.cellAt(row, 0)),
            reason:
                'Viewport row $row at offset 0 should match screen row $row',
          );
        }
      });
    });

    group('new data after resize renders correctly', () {
      test('writing after grow shows content on screen', () {
        final t = Terminal(cols: 80, rows: 24);
        addTearDown(t.dispose);

        for (var i = 0; i < 50; i++) {
          t.write(Uint8List.fromList('Line_$i\r\n'.codeUnits));
        }

        t.resize(cols: 25, rows: 47);

        t.write(Uint8List.fromList('\x1b[2J\x1b[H'.codeUnits));
        for (var i = 0; i < 10; i++) {
          t.write(Uint8List.fromList('NewLine_$i\r\n'.codeUnits));
        }

        final viewport = TerminalViewport(
          screen: t.screen,
          scrollback: t.scrollback,
          scrollOffset: 0,
        );

        expect(
          viewport.lineAt(0).text.trimRight(),
          startsWith('NewLine_0'),
          reason: 'Viewport row 0 at offset 0 should show new content',
        );
      });

      test('writing after shrink shows content on screen', () {
        final t = Terminal(cols: 80, rows: 24);
        addTearDown(t.dispose);

        for (var i = 0; i < 50; i++) {
          t.write(Uint8List.fromList('Line_$i\r\n'.codeUnits));
        }

        t.resize(cols: 25, rows: 10);

        t.write(Uint8List.fromList('\x1b[2J\x1b[H'.codeUnits));
        for (var i = 0; i < 5; i++) {
          t.write(Uint8List.fromList('NewLine_$i\r\n'.codeUnits));
        }

        final viewport = TerminalViewport(
          screen: t.screen,
          scrollback: t.scrollback,
          scrollOffset: 0,
        );

        expect(
          viewport.lineAt(0).text.trimRight(),
          startsWith('NewLine_0'),
          reason: 'Viewport row 0 at offset 0 should show new content',
        );
      });
    });

    group('SSH-like scenario', () {
      test('large scrollback + grow resize + viewport at offset 0', () {
        final t = Terminal(cols: 80, rows: 24);
        addTearDown(t.dispose);

        for (var i = 0; i < 620; i++) {
          t.write(Uint8List.fromList('ssh_output_$i\r\n'.codeUnits));
        }

        expect(t.scrollback.length, greaterThan(500));

        t.resize(cols: 25, rows: 47);

        final scrollbackLen = t.scrollback.length;

        final viewportAtBottom = TerminalViewport(
          screen: t.screen,
          scrollback: t.scrollback,
          scrollOffset: 0,
        );

        expect(
          viewportAtBottom.cellAt(0, 0),
          equals(t.screen.cellAt(0, 0)),
          reason:
              'Viewport row 0 at offset 0 should be '
              'screen row 0, not scrollback',
        );

        final viewportAtTop = TerminalViewport(
          screen: t.screen,
          scrollback: t.scrollback,
          scrollOffset: scrollbackLen,
        );

        expect(
          viewportAtTop.lineAt(0).text.trimRight(),
          startsWith('ssh_output_0'),
          reason:
              'Viewport at max scroll offset should show first scrollback line',
        );
      });

      test('large scrollback + shrink resize + new SSH data', () {
        final t = Terminal(cols: 80, rows: 24);
        addTearDown(t.dispose);

        for (var i = 0; i < 620; i++) {
          t.write(Uint8List.fromList('ssh_output_$i\r\n'.codeUnits));
        }

        t.resize(cols: 25, rows: 10);

        t.write(Uint8List.fromList('\x1b[2J\x1b[H'.codeUnits));
        for (var i = 0; i < 8; i++) {
          t.write(Uint8List.fromList('fresh_$i\r\n'.codeUnits));
        }

        final viewport = TerminalViewport(
          screen: t.screen,
          scrollback: t.scrollback,
          scrollOffset: 0,
        );

        expect(
          viewport.lineAt(0).text.trimRight(),
          startsWith('fresh_0'),
          reason:
              'After SSH redraw, viewport offset 0 should show fresh content',
        );
      });
    });

    group('resize preserves content', () {
      test('shrink with cursor at bottom keeps content on screen', () {
        final t = Terminal(cols: 10, rows: 10);
        addTearDown(t.dispose);

        for (var i = 0; i < 10; i++) {
          if (i < 9) {
            t.write(Uint8List.fromList('Row_$i\r\n'.codeUnits));
          } else {
            t.write(Uint8List.fromList('Row_$i'.codeUnits));
          }
        }

        t.resize(cols: 10, rows: 5);

        final all = TerminalDump.nonEmptyContent(t);
        expect(all.length, 10);
        expect(all[0], startsWith('Row_0'));
        expect(all[9], startsWith('Row_9'));
      });

      test('shrink preserves all content across scrollback and screen', () {
        final t = Terminal(cols: 10, rows: 10);
        addTearDown(t.dispose);

        t.write(Uint8List.fromList('A\r\nB\r\nC'.codeUnits));

        t.resize(cols: 10, rows: 5);

        final all = TerminalDump.nonEmptyContent(t);
        expect(all.length, 3);
        expect(all[0], startsWith('A'));
        expect(all[1], startsWith('B'));
        expect(all[2], startsWith('C'));
      });
    });

    group('viewport coordinate mapping after resize', () {
      test('viewportRowToAbsolute maps correctly with scrollOffset=0', () {
        final t = Terminal(cols: 80, rows: 24);
        addTearDown(t.dispose);

        for (var i = 0; i < 100; i++) {
          t.write(Uint8List.fromList('Line_$i\r\n'.codeUnits));
        }

        t.resize(cols: 25, rows: 47);

        final viewport = TerminalViewport(
          screen: t.screen,
          scrollback: t.scrollback,
          scrollOffset: 0,
        );

        final scrollbackLen = t.scrollback.length;

        expect(
          viewport.viewportRowToAbsolute(0),
          scrollbackLen,
          reason:
              'Viewport row 0 at offset 0 should map to '
              'absolute row = scrollback length',
        );

        final absoluteRow = viewport.viewportRowToAbsolute(0);
        final screenRow = absoluteRow - scrollbackLen;
        expect(screenRow, 0);
      });

      test(
        'viewportRowToAbsolute maps correctly with scrollOffset=scrollbackLen',
        () {
          final t = Terminal(cols: 80, rows: 24);
          addTearDown(t.dispose);

          for (var i = 0; i < 100; i++) {
            t.write(Uint8List.fromList('Line_$i\r\n'.codeUnits));
          }

          t.resize(cols: 25, rows: 47);

          final scrollbackLen = t.scrollback.length;

          final viewport = TerminalViewport(
            screen: t.screen,
            scrollback: t.scrollback,
            scrollOffset: scrollbackLen,
          );

          expect(viewport.viewportRowToAbsolute(0), 0);
        },
      );
    });

    group('content continuity through resize', () {
      test('content continuous at all scroll offsets after shrink', () {
        final t = Terminal(cols: 10, rows: 6, scrollbackLimit: 100);
        addTearDown(t.dispose);
        for (var i = 0; i < 6; i++) {
          t.write(Uint8List.fromList('Line_$i\r\n'.codeUnits));
        }

        t.resize(cols: 10, rows: 3);

        final allContent = TerminalDump.nonEmptyContent(t);

        for (var offset = 0; offset <= t.scrollback.length; offset++) {
          final viewport = TerminalViewport(
            screen: t.screen,
            scrollback: t.scrollback,
            scrollOffset: offset,
          );
          for (var row = 0; row < viewport.rows; row++) {
            final absoluteRow = viewport.viewportRowToAbsolute(row);
            if (absoluteRow >= 0 &&
                absoluteRow < t.scrollback.length + t.screen.rows) {
              final lineText = viewport.lineAt(row).text.trimRight();
              if (lineText.isNotEmpty) {
                expect(allContent, contains(lineText));
              }
            }
          }
        }
      });

      test('no empty gaps in content region after shrink', () {
        final t = Terminal(cols: 10, rows: 5, scrollbackLimit: 100);
        addTearDown(t.dispose);
        t.write(
          Uint8List.fromList('AAA\r\nBBB\r\nCCC\r\nDDD\r\nEEE'.codeUnits),
        );

        t.resize(cols: 10, rows: 3);

        final allContent = TerminalDump.allContent(t);
        final nonEmptyIndices = <int>[];
        for (var i = 0; i < allContent.length; i++) {
          if (allContent[i].trimRight().isNotEmpty) {
            nonEmptyIndices.add(i);
          }
        }

        for (var i = 0; i < nonEmptyIndices.length - 1; i++) {
          expect(
            nonEmptyIndices[i + 1] - nonEmptyIndices[i],
            1,
            reason:
                'Gap found between content rows at indices '
                '${nonEmptyIndices[i]} and ${nonEmptyIndices[i + 1]}',
          );
        }
      });

      test('all written content accessible via scrollback + screen', () {
        final t = Terminal(cols: 80, rows: 24);
        addTearDown(t.dispose);

        final writtenLines = <String>[];
        for (var i = 0; i < 100; i++) {
          writtenLines.add('Content_$i');
          t.write(Uint8List.fromList('Content_$i\r\n'.codeUnits));
        }

        t.resize(cols: 25, rows: 10);

        final all = TerminalDump.nonEmptyContent(t);
        for (final line in writtenLines) {
          final prefix = line.length > 10 ? line.substring(0, 10) : line;
          expect(
            all.any((c) => c.startsWith(prefix)),
            isTrue,
            reason:
                'Content "$line" should be accessible '
                'after resize',
          );
        }
      });

      test('viewport shows complete content by scrolling', () {
        final t = Terminal(cols: 80, rows: 24);
        addTearDown(t.dispose);

        for (var i = 0; i < 100; i++) {
          t.write(Uint8List.fromList('Line_$i\r\n'.codeUnits));
        }

        t.resize(cols: 80, rows: 10);

        final scrollbackLen = t.scrollback.length;

        final allViewportContent = <String>[];
        for (var offset = scrollbackLen; offset >= 0; offset--) {
          final viewport = TerminalViewport(
            screen: t.screen,
            scrollback: t.scrollback,
            scrollOffset: offset,
          );
          if (offset == scrollbackLen) {
            for (var row = 0; row < viewport.rows; row++) {
              allViewportContent.add(viewport.lineAt(row).text.trimRight());
            }
          } else {
            allViewportContent.add(
              viewport.lineAt(viewport.rows - 1).text.trimRight(),
            );
          }
        }

        final nonEmpty = allViewportContent.where((l) => l.isNotEmpty).toSet();
        for (var i = 0; i < 100; i++) {
          expect(
            nonEmpty.any((c) => c.startsWith('Line_$i')),
            isTrue,
            reason: 'Line_$i should be visible at some scroll offset',
          );
        }
      });
    });

    group('scrollback lines after column shrink', () {
      test('scrollback lines retain original width', () {
        final t = Terminal(cols: 10, rows: 4, scrollbackLimit: 100);
        addTearDown(t.dispose);
        t.write(Uint8List.fromList('ABCDEFGHIJ\r\nKLMNOPQRST\r\n'.codeUnits));
        t.write(Uint8List.fromList('Row3\r\nRow4'.codeUnits));

        t.resize(cols: 5, rows: 2);

        for (var i = 0; i < t.scrollback.length; i++) {
          final line = t.scrollback.lineAt(i);
          if (line.text.trimRight().startsWith('ABCDEFGHIJ')) {
            expect(line.cellAt(9).content, 'J');
            break;
          }
        }
      });
    });

    group('viewport shows correct data after resize', () {
      test('viewport at scrollOffset=0 shows screen after resize', () {
        final t = Terminal(cols: 10, rows: 6, scrollbackLimit: 100);
        addTearDown(t.dispose);
        for (var i = 0; i < 6; i++) {
          t.write(Uint8List.fromList('Line_$i\r\n'.codeUnits));
        }

        t.resize(cols: 10, rows: 3);

        final viewportLines = TerminalDump.viewportContent(t);
        final screenLines = TerminalDump.screenContent(t);
        expect(viewportLines, screenLines);
      });

      test('viewport at max scrollOffset shows top of scrollback', () {
        final t = Terminal(cols: 10, rows: 4, scrollbackLimit: 100);
        addTearDown(t.dispose);
        for (var i = 0; i < 8; i++) {
          t.write(Uint8List.fromList('Line_$i\r\n'.codeUnits));
        }

        t.resize(cols: 10, rows: 3);

        final maxOffset = t.scrollback.length;
        final viewport = TerminalViewport(
          screen: t.screen,
          scrollback: t.scrollback,
          scrollOffset: maxOffset,
        );

        final firstLine = viewport.lineAt(0).text.trimRight();
        final firstScrollbackLine = t.scrollback.lineAt(0).text.trimRight();
        expect(firstLine, firstScrollbackLine);
      });
    });

    group('column resize interaction', () {
      test('narrowing columns truncates long lines on screen', () {
        final t = Terminal(cols: 80, rows: 5);
        addTearDown(t.dispose);

        t.write(
          Uint8List.fromList('ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890'.codeUnits),
        );

        t.resize(cols: 10, rows: 5);

        expect(t.screen.cellAt(0, 0).content, 'A');
        expect(t.screen.cellAt(0, 9).content, 'J');
      });

      test('writing new content after column shrink uses new width', () {
        final t = Terminal(cols: 80, rows: 5);
        addTearDown(t.dispose);

        t.resize(cols: 10, rows: 5);

        t.write(Uint8List.fromList('ABCDEFGHIJKLMNO'.codeUnits));

        expect(t.screen.cellAt(0, 0).content, 'A');
        expect(t.screen.cellAt(0, 9).content, 'J');
        expect(t.screen.cellAt(1, 0).content, 'K');
        expect(t.screen.cellAt(1, 4).content, 'O');
      });
    });
  });
}

@Tags(['ffi'])
library;

import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

import 'helpers/terminal_dump.dart';

void main() {
  group('Terminal', () {
    late Terminal terminal;

    setUp(() {
      terminal = Terminal(cols: 80, rows: 24);
    });

    tearDown(() {
      terminal.dispose();
    });

    test('initial dimensions', () {
      expect(terminal.screen.cols, 80);
      expect(terminal.screen.rows, 24);
    });

    test('write bytes and read screen', () {
      terminal.write(.fromList('Hello'.codeUnits));
      expect(terminal.screen.cellAt(0, 0).content, 'H');
      expect(terminal.screen.cellAt(0, 4).content, 'o');
    });

    test('cursor tracks position', () {
      terminal.write(.fromList('Hi'.codeUnits));
      expect(terminal.cursor.col, 2);
      expect(terminal.cursor.row, 0);
    });

    test('cursor visibility', () {
      terminal.write(.fromList('\x1b[?25l'.codeUnits));
      expect(terminal.cursor.visible, isFalse);

      terminal.write(.fromList('\x1b[?25h'.codeUnits));
      expect(terminal.cursor.visible, isTrue);
    });

    test('modes track terminal state', () {
      terminal.write(.fromList('\x1b[?2004h'.codeUnits));
      expect(terminal.modes.bracketedPaste, isTrue);
    });

    test('alternate screen switch', () {
      terminal.write(.fromList('Primary'.codeUnits));
      terminal.write(.fromList('\x1b[?1049h'.codeUnits));

      expect(terminal.modes.alternateScreen, isTrue);
      expect(terminal.screen.cellAt(0, 0), Cell.empty);

      terminal.write(.fromList('\x1b[?1049l'.codeUnits));

      expect(terminal.modes.alternateScreen, isFalse);
      expect(terminal.screen.cellAt(0, 0).content, 'P');
    });

    test('styled text', () {
      terminal.write(.fromList('\x1b[1;31mBold Red'.codeUnits));
      final cell = terminal.screen.cellAt(0, 0);
      expect(cell.content, 'B');
      expect(cell.style.bold, isTrue);
      expect(cell.foreground, const RgbColor(204, 102, 102));
    });

    test('multi-byte UTF-8', () {
      terminal.write(.fromList([0xC3, 0xA9])); // é
      expect(terminal.screen.cellAt(0, 0).content, '\u00E9');
    });

    test('split UTF-8 across writes', () {
      terminal.write(.fromList([0xC3]));
      terminal.write(.fromList([0xA9]));
      expect(terminal.screen.cellAt(0, 0).content, '\u00E9');
    });

    test('lineAt returns line content', () {
      terminal.write(.fromList('Hello World'.codeUnits));
      final line = terminal.screen.lineAt(0);
      expect(line.text, startsWith('Hello World'));
    });

    test('CRLF line breaks', () {
      terminal.write(.fromList('Line1\r\nLine2'.codeUnits));
      expect(terminal.screen.cellAt(0, 0).content, 'L');
      expect(terminal.screen.cellAt(1, 0).content, 'L');
      expect(terminal.screen.lineAt(0).text, startsWith('Line1'));
      expect(terminal.screen.lineAt(1).text, startsWith('Line2'));
    });

    group('events', () {
      test('onBell fires', () {
        var bellCount = 0;
        terminal.onBell.listen((_) => bellCount++);
        terminal.write(.fromList([0x07]));
        expect(bellCount, 1);
      });

      test('onTitleChanged fires', () {
        String? title;
        terminal.onTitleChanged.listen((t) => title = t);
        terminal.write(.fromList('\x1b]0;Test Title\x07'.codeUnits));
        expect(title, 'Test Title');
      });

      test('onScreenChanged fires on write', () {
        var changeCount = 0;
        terminal.onScreenChanged.listen((_) => changeCount++);
        terminal.write(.fromList('A'.codeUnits));
        expect(changeCount, greaterThan(0));
      });

      test('onScreenChanged fires on resize', () {
        var changeCount = 0;
        terminal.onScreenChanged.listen((_) => changeCount++);
        terminal.resize(cols: 120, rows: 40);
        expect(changeCount, 1);
      });
    });

    group('hasContentChanges', () {
      test('writing content sets hasContentChanges', () {
        terminal.clearContentChanges();
        terminal.write(.fromList('A'.codeUnits));
        expect(terminal.hasContentChanges, isTrue);
      });

      test('clearContentChanges resets the flag', () {
        terminal.write(.fromList('A'.codeUnits));
        terminal.clearContentChanges();
        expect(terminal.hasContentChanges, isFalse);
      });

      test('cursor-only move does not set hasContentChanges', () {
        terminal.write(.fromList('Hello'.codeUnits));
        terminal.clearContentChanges();
        terminal.write(.fromList('\x1b[H'.codeUnits));
        expect(terminal.hasContentChanges, isFalse);
      });

      test('accumulates across multiple writes', () {
        terminal.clearContentChanges();
        terminal.write(.fromList('X'.codeUnits));
        terminal.write(.fromList('\x1b[H'.codeUnits));
        expect(terminal.hasContentChanges, isTrue);
      });
    });

    group('resize', () {
      test('updates dimensions', () {
        terminal.resize(cols: 120, rows: 40);
        expect(terminal.screen.cols, 120);
        expect(terminal.screen.rows, 40);
      });

      test('clamps cursor', () {
        terminal.write(.fromList('\x1b[24;80H'.codeUnits));
        terminal.resize(cols: 40, rows: 10);
        expect(terminal.cursor.row, lessThan(10));
        expect(terminal.cursor.col, lessThan(40));
      });

      test('shrinking rows pushes bottom lines to scrollback', () {
        final t = Terminal(cols: 10, rows: 5);
        addTearDown(t.dispose);
        for (var i = 0; i < 5; i++) {
          t.write(.fromList('Line$i\r\n'.codeUnits));
        }

        final scrollbackBefore = t.scrollback.length;
        t.resize(cols: 10, rows: 3);
        expect(t.scrollback.length, greaterThan(scrollbackBefore));
      });

      test('shrinking rows preserves content in scrollback', () {
        final t = Terminal(cols: 10, rows: 4);
        addTearDown(t.dispose);
        t.write(.fromList('AAA\r\nBBB\r\nCCC\r\nDDD'.codeUnits));
        expect(t.screen.cellAt(0, 0).content, 'A');
        expect(t.screen.cellAt(3, 0).content, 'D');

        final scrollbackBefore = t.scrollback.length;
        t.resize(cols: 10, rows: 2);

        expect(t.scrollback.length, scrollbackBefore + 2);

        final pushed0 = t.scrollback.lineAt(scrollbackBefore);
        final pushed1 = t.scrollback.lineAt(scrollbackBefore + 1);
        expect(pushed0.text, startsWith('AAA'));
        expect(pushed1.text, startsWith('BBB'));

        expect(t.screen.cellAt(0, 0).content, 'C');
        expect(t.screen.cellAt(1, 0).content, 'D');
      });

      test('shrinking rows adjusts cursor position', () {
        final t = Terminal(cols: 10, rows: 5);
        addTearDown(t.dispose);
        t.write(.fromList('A\r\nB\r\nC\r\nD\r\nE'.codeUnits));
        expect(t.cursor.row, 4);

        t.resize(cols: 10, rows: 3);
        expect(t.cursor.row, 2);
      });

      test('growing rows does not affect scrollback', () {
        final t = Terminal(cols: 10, rows: 3);
        addTearDown(t.dispose);
        t.write(.fromList('AAA\r\nBBB\r\nCCC'.codeUnits));

        final scrollbackBefore = t.scrollback.length;
        t.resize(cols: 10, rows: 6);
        expect(t.scrollback.length, scrollbackBefore);
      });

      test('no content duplication after shrink', () {
        final t = Terminal(cols: 10, rows: 6);
        addTearDown(t.dispose);
        for (var i = 0; i < 6; i++) {
          t.write(.fromList('Row_$i\r\n'.codeUnits));
        }

        t.resize(cols: 10, rows: 3);

        expect(TerminalDump.hasContentOverlap(t), isFalse);
      });

      test('content order preserved after shrink', () {
        final t = Terminal(cols: 10, rows: 5);
        addTearDown(t.dispose);
        t.write(.fromList('AAA\r\nBBB\r\nCCC\r\nDDD\r\nEEE'.codeUnits));

        t.resize(cols: 10, rows: 3);

        final all = TerminalDump.nonEmptyContent(t);
        expect(all[0], startsWith('AAA'));
        expect(all[1], startsWith('BBB'));
        expect(all[2], startsWith('CCC'));
        expect(all[3], startsWith('DDD'));
        expect(all[4], startsWith('EEE'));
      });

      test('all content accessible after shrink', () {
        final t = Terminal(cols: 10, rows: 5);
        addTearDown(t.dispose);
        t.write(.fromList('AAA\r\nBBB\r\nCCC\r\nDDD\r\nEEE'.codeUnits));

        t.resize(cols: 10, rows: 3);

        final nonEmpty = TerminalDump.nonEmptyContent(t);
        expect(nonEmpty.length, 5);
      });

      test('shrink-grow cycle preserves screen content', () {
        final t = Terminal(cols: 10, rows: 6);
        addTearDown(t.dispose);
        t.write(.fromList('AAA\r\nBBB\r\nCCC\r\nDDD\r\nEEE\r\nFFF'.codeUnits));

        t.resize(cols: 10, rows: 3);
        final afterShrink = TerminalDump.screenContent(
          t,
        ).map((l) => l.trimRight()).where((l) => l.isNotEmpty).toList();

        t.resize(cols: 10, rows: 6);
        final afterGrow = TerminalDump.screenContent(
          t,
        ).map((l) => l.trimRight()).where((l) => l.isNotEmpty).toList();

        for (final line in afterShrink) {
          expect(afterGrow, contains(line));
        }
      });

      test('multiple resize cycles maintain integrity', () {
        final t = Terminal(cols: 10, rows: 8);
        addTearDown(t.dispose);
        for (var i = 0; i < 8; i++) {
          t.write(.fromList('Line$i\r\n'.codeUnits));
        }

        t.resize(cols: 10, rows: 4);
        expect(TerminalDump.hasContentOverlap(t), isFalse);

        t.resize(cols: 10, rows: 6);
        expect(TerminalDump.hasContentOverlap(t), isFalse);

        t.resize(cols: 10, rows: 2);
        expect(TerminalDump.hasContentOverlap(t), isFalse);

        final all = TerminalDump.nonEmptyContent(t);
        for (var i = 0; i < all.length - 1; i++) {
          final currentNum = int.tryParse(
            all[i].replaceAll(RegExp('[^0-9]'), ''),
          );
          final nextNum = int.tryParse(
            all[i + 1].replaceAll(RegExp('[^0-9]'), ''),
          );
          if (currentNum != null && nextNum != null) {
            expect(currentNum, lessThan(nextNum));
          }
        }
      });

      test('styled content survives resize in scrollback', () {
        final t = Terminal(cols: 20, rows: 4);
        addTearDown(t.dispose);
        t.write(.fromList('\x1b[1;31mBoldRed\x1b[0m\r\n'.codeUnits));
        t.write(.fromList('Normal\r\n'.codeUnits));
        t.write(.fromList('Row3\r\n'.codeUnits));
        t.write(.fromList('Row4'.codeUnits));

        t.resize(cols: 20, rows: 2);

        expect(t.scrollback.length, greaterThan(0));
        final firstScrollbackLine = t.scrollback.lineAt(
          t.scrollback.length - 2,
        );
        final cell = firstScrollbackLine.cellAt(0);
        expect(cell.content, 'B');
        expect(cell.style.bold, isTrue);
        expect(cell.foreground, const RgbColor(204, 102, 102));
      });

      test('column shrink preserves content within new width', () {
        final t = Terminal(cols: 10, rows: 3);
        addTearDown(t.dispose);
        t.write(.fromList('ABCDEFGHIJ'.codeUnits));

        t.resize(cols: 5, rows: 3);

        expect(t.screen.cellAt(0, 0).content, 'A');
        expect(t.screen.cellAt(0, 4).content, 'E');
      });

      test('column grow pads with empty cells', () {
        final t = Terminal(cols: 5, rows: 3);
        addTearDown(t.dispose);
        t.write(.fromList('ABCDE'.codeUnits));

        t.resize(cols: 10, rows: 3);

        expect(t.screen.cellAt(0, 0).content, 'A');
        expect(t.screen.cellAt(0, 4).content, 'E');
        expect(t.screen.cellAt(0, 5), Cell.empty);
        expect(t.screen.cellAt(0, 9), Cell.empty);
      });
    });

    group('screen', () {
      group('initialization', () {
        test('fresh terminal has all empty cells', () {
          final t = Terminal(cols: 80, rows: 24);
          addTearDown(t.dispose);
          _expectAllCellsEmpty(t);
        });

        test('fresh terminal has empty scrollback', () {
          final t = Terminal(cols: 80, rows: 24);
          addTearDown(t.dispose);
          expect(t.scrollback.length, 0);
        });

        test('fresh terminal has cursor at origin', () {
          final t = Terminal(cols: 80, rows: 24);
          addTearDown(t.dispose);
          expect(t.cursor.row, 0);
          expect(t.cursor.col, 0);
        });

        test('recreated terminal has all empty cells', () {
          var t = Terminal(cols: 80, rows: 24);
          t.write(.fromList('Hello World'.codeUnits));
          t.dispose();

          t = Terminal(cols: 80, rows: 24);
          addTearDown(t.dispose);
          _expectAllCellsEmpty(t);
        });

        test('recreated terminal has empty scrollback', () {
          var t = Terminal(cols: 80, rows: 24);
          t.write(.fromList('Hello\r\nWorld\r\n'.codeUnits));
          t.dispose();

          t = Terminal(cols: 80, rows: 24);
          addTearDown(t.dispose);
          expect(t.scrollback.length, 0);
        });

        test('multiple dispose-recreate cycles produce clean screens', () {
          for (var i = 0; i < 5; i++) {
            final t = Terminal(cols: 40, rows: 10);
            _expectAllCellsEmpty(t);
            t.write(.fromList('Cycle $i data fill'.codeUnits));
            t.dispose();
          }
        });

        test(
          'recreated terminal with different dimensions has all empty cells',
          () {
            var t = Terminal(cols: 80, rows: 24);
            t.write(.fromList('Fill the screen'.codeUnits));
            t.dispose();

            t = Terminal(cols: 120, rows: 40);
            addTearDown(t.dispose);
            _expectAllCellsEmpty(t);
          },
        );
      });

      group('multi-instance', () {
        test('two concurrent terminals have independent state', () {
          final t1 = Terminal(cols: 80, rows: 24);
          addTearDown(t1.dispose);
          final t2 = Terminal(cols: 80, rows: 24);
          addTearDown(t2.dispose);

          t1.write(.fromList('Terminal One'.codeUnits));
          t2.write(.fromList('Terminal Two'.codeUnits));

          expect(t1.screen.cellAt(0, 0).content, 'T');
          expect(t1.screen.cellAt(0, 9).content, 'O');
          expect(t2.screen.cellAt(0, 0).content, 'T');
          expect(t2.screen.cellAt(0, 9).content, 'T');
        });

        test('writing to one terminal does not affect the other', () {
          final t1 = Terminal(cols: 80, rows: 24);
          addTearDown(t1.dispose);
          final t2 = Terminal(cols: 80, rows: 24);
          addTearDown(t2.dispose);

          t1.write(.fromList('AAAA'.codeUnits));
          _expectAllCellsEmpty(t2);
        });

        test('disposing one terminal does not affect the other', () {
          final t1 = Terminal(cols: 80, rows: 24);
          final t2 = Terminal(cols: 80, rows: 24);
          addTearDown(t2.dispose);

          t2.write(.fromList('Still alive'.codeUnits));
          t1.dispose();

          expect(t2.screen.cellAt(0, 0).content, 'S');
          expect(t2.screen.cellAt(0, 6).content, 'a');
          t2.write(.fromList('\r\nMore data'.codeUnits));
          expect(t2.screen.cellAt(1, 0).content, 'M');
        });

        test('new terminal created after dispose has clean screen', () {
          final t1 = Terminal(cols: 80, rows: 24);
          t1.write(.fromList('Fill with data'.codeUnits));
          t1.dispose();

          final t2 = Terminal(cols: 80, rows: 24);
          addTearDown(t2.dispose);
          _expectAllCellsEmpty(t2);
          expect(t2.scrollback.length, 0);
          expect(t2.cursor.row, 0);
          expect(t2.cursor.col, 0);
        });
      });
    });

    group('dispose', () {
      test('double dispose is safe', () {
        terminal.dispose();
        terminal.dispose();
      });

      test('all public members throw after dispose', () {
        terminal.dispose();

        final publicMembers = <String, void Function()>{
          'write': () => terminal.write(.fromList([0x41])),
          'screen': () => terminal.screen,
          'cursor': () => terminal.cursor,
          'modes': () => terminal.modes,
          'scrollback': () => terminal.scrollback,
          'hasContentChanges': () => terminal.hasContentChanges,
          'clearContentChanges': () => terminal.clearContentChanges(),
          'resize': () => terminal.resize(cols: 40, rows: 10),
        };

        for (final MapEntry(:key, :value) in publicMembers.entries) {
          expect(value, throwsA(isA<DisposedException>()), reason: key);
        }
      });
    });
  });
}

void _expectAllCellsEmpty(Terminal t) {
  for (var row = 0; row < t.screen.rows; row++) {
    for (var col = 0; col < t.screen.cols; col++) {
      expect(
        t.screen.cellAt(row, col),
        Cell.empty,
        reason: 'cell at ($row, $col) should be empty',
      );
    }
  }
}

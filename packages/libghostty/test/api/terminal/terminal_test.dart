import 'dart:convert';
import 'dart:typed_data';

import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

import '../../helpers/setup.dart';
import 'helpers/cell_reader.dart';
import 'helpers/terminal_dump.dart';

void main() {
  setUp(() => testEnvironment);

  group('Terminal', () {
    late Terminal terminal;

    setUp(() {
      terminal = Terminal(cols: 80, rows: 24);
    });

    tearDown(() {
      terminal.dispose();
    });

    group('dispose', () {
      test('is idempotent for the terminal', () {
        terminal.dispose();

        expect(terminal.dispose, returnsNormally);
      });

      test('rejects all operations after terminal disposal', () {
        terminal.dispose();

        expect(() => terminal.title, throwsStateError);
        expect(
          () => terminal.write(Uint8List.fromList([0x61])),
          throwsStateError,
        );
      });

      test('succeeds after a callback error', () {
        final error = StateError('bell failed');
        terminal.onBell = () => throw error;
        expect(
          () => terminal.write(Uint8List.fromList([0x07])),
          throwsA(same(error)),
        );

        expect(terminal.dispose, returnsNormally);
      });
    });

    group('geometry', () {
      test('returns cell and pixel dimensions', () {
        terminal.resize(cols: 40, rows: 10, cellWidthPx: 8, cellHeightPx: 16);

        final result = terminal.geometry;

        expect(
          result,
          const TerminalGeometry(
            cols: 40,
            rows: 10,
            widthPx: 320,
            heightPx: 160,
          ),
        );
      });
    });

    group('VT parser state', () {
      test('tracks OSC 133 prompt boundaries and alternate screen', () {
        terminal.write(
          Uint8List.fromList([0x1b, 0x5d, 0x31, 0x33, 0x33, 0x3b, 0x41, 0x07]),
        );

        expect(terminal.isCursorAtPrompt, isTrue);

        terminal.write(
          Uint8List.fromList([0x1b, 0x5b, 0x3f, 0x31, 0x30, 0x34, 0x39, 0x68]),
        );

        expect(terminal.isCursorAtPrompt, isFalse);
      });

      test('reports ground and consumes through ground', () {
        expect(terminal.isVtGround, isTrue);

        terminal.write(Uint8List.fromList([0x1b, 0x5b]));

        expect(terminal.isVtGround, isFalse);
        expect(
          terminal.writeUntilGround(Uint8List.fromList('31mA'.codeUnits)),
          3,
        );

        terminal.write(Uint8List.fromList([0x41]));

        expect(terminal.isVtGround, isTrue);
      });

      test('returns null when all input is consumed before ground', () {
        terminal.write(Uint8List.fromList([0x1b, 0x5b]));

        expect(
          terminal.writeUntilGround(Uint8List.fromList('31'.codeUnits)),
          isNull,
        );
      });

      test('reaches ground after completing partial UTF-8', () {
        terminal.write(Uint8List.fromList([0xc2]));

        expect(terminal.isVtGround, isFalse);
        expect(terminal.writeUntilGround(Uint8List.fromList([0xa2, 0x41])), 1);
      });

      test('returns zero when already in ground', () {
        expect(terminal.writeUntilGround(Uint8List.fromList([0x41])), 0);
        expect(terminal.isVtGround, isTrue);
      });
    });

    group('unknown sequences', () {
      test('copies binary APC content and reports truncation', () {
        TerminalUnknownSequence? sequence;
        terminal.unknownSequenceMaxBytes = 2;
        terminal.onUnknownSequence = (value) => sequence = value;

        terminal.write(
          Uint8List.fromList([0x1b, 0x5f, 0x00, 0x01, 0x02, 0x1b, 0x5c]),
        );

        expect(sequence?.tag, TerminalUnknownSequenceTag.apc);
        expect(sequence?.content, Uint8List.fromList([0x00, 0x01]));
        expect(sequence?.truncated, isTrue);
      });

      test('copies unknown OSC content and its terminator', () {
        TerminalUnknownSequence? sequence;
        terminal.unknownSequenceMaxBytes = 32;
        terminal.onUnknownSequence = (value) => sequence = value;

        terminal.write(Uint8List.fromList('\x1b]7400;x\x1b\\'.codeUnits));

        expect(sequence?.tag, TerminalUnknownSequenceTag.osc);
        expect(sequence?.content, Uint8List.fromList('7400;x'.codeUnits));
        expect(sequence?.terminator, OscTerminator.st);
      });

      test('clears the callback and capture limit', () {
        var count = 0;
        terminal.unknownSequenceMaxBytes = 32;
        terminal.onUnknownSequence = (_) => count++;
        terminal.onUnknownSequence = null;
        terminal.unknownSequenceMaxBytes = null;

        terminal.write(Uint8List.fromList([0x1b, 0x5f, 0x61, 0x1b, 0x5c]));

        expect(count, 0);
      });
    });

    group('terminfoName', () {
      test('answers and clears XTGETTCAP TN queries', () {
        final output = <Uint8List>[];
        terminal.terminfoName = 'xterm-256color';
        terminal.onWritePty = output.add;

        terminal.write(
          Uint8List.fromList([
            0x1b,
            0x50,
            0x2b,
            0x71,
            0x35,
            0x34,
            0x34,
            0x45,
            0x1b,
            0x5c,
          ]),
        );

        expect(
          String.fromCharCodes(output.single),
          contains('787465726D2D323536636F6C6F72'),
        );
        output.clear();
        terminal.terminfoName = null;

        terminal.write(
          Uint8List.fromList([
            0x1b,
            0x50,
            0x2b,
            0x71,
            0x35,
            0x34,
            0x34,
            0x45,
            0x1b,
            0x5c,
          ]),
        );

        expect(output, isEmpty);
      });

      test('maps the 128 UTF-8 byte limit to InvalidValueException', () {
        terminal.terminfoName = 'xterm-256color';

        expect(
          () => terminal.terminfoName = 'a' * 129,
          throwsA(isA<InvalidValueException>()),
        );
      });
    });

    group('scrollbackMaxLines', () {
      test('gets the value set through the setter', () {
        terminal.scrollbackMaxLines = 100;

        expect(terminal.scrollbackMaxLines, 100);
      });

      test('returns null when cleared', () {
        terminal.scrollbackMaxLines = null;

        expect(terminal.scrollbackMaxLines, isNull);
      });
    });

    group('scrollbackMaxBytes', () {
      test('gets the value set through the setter', () {
        terminal.scrollbackMaxBytes = 1024;

        expect(terminal.scrollbackMaxBytes, 1024);
      });
    });

    group('continuationMaxBytes', () {
      test('gets the value set through the setter', () {
        terminal.continuationMaxBytes = 128;

        expect(terminal.continuationMaxBytes, 128);
      });

      test('rejects negative values', () {
        expect(
          () => terminal.continuationMaxBytes = -1,
          throwsA(isA<RangeError>()),
        );
      });
    });

    group('continuation', () {
      test('returns unfinished input after tracking is enabled', () {
        terminal.continuationMaxBytes = 128;

        terminal.write(Uint8List.fromList([0x1b, 0x5d]));

        expect(terminal.continuation, [0x1b, 0x5d]);
      });

      test('throws when tracking is disabled', () {
        expect(
          () => terminal.continuation,
          throwsA(isA<InvalidValueException>()),
        );
      });

      test('writes unfinished input to the callback', () {
        terminal.continuationMaxBytes = 128;
        terminal.write(Uint8List.fromList([0x1b, 0x5d]));
        final chunks = <int>[];

        terminal.writeContinuation((chunk) {
          chunks.addAll(chunk);
          return true;
        });

        expect(chunks, [0x1b, 0x5d]);
      });

      test('maps a rejected chunk to an IO exception', () {
        terminal.continuationMaxBytes = 128;
        terminal.write(Uint8List.fromList([0x1b, 0x5d]));

        expect(
          () => terminal.writeContinuation((_) => false),
          throwsA(isA<IoException>()),
        );
      });

      test('rethrows callback errors after the operation', () {
        terminal.continuationMaxBytes = 128;
        terminal.write(Uint8List.fromList([0x1b, 0x5d]));
        final error = StateError('continuation writer failed');

        expect(
          () => terminal.writeContinuation((_) => throw error),
          throwsA(same(error)),
        );
      });
    });

    group('onDesktopNotification', () {
      test('receives OSC 9 notifications', () {
        DesktopNotification? notification;
        terminal.onDesktopNotification = (value) => notification = value;

        terminal.write(
          Uint8List.fromList('\x1b]9;Build finished\x07'.codeUnits),
        );

        expect(
          notification,
          const DesktopNotification(title: '', body: 'Build finished'),
        );
      });
    });

    group('onProgressReport', () {
      test('receives determinate OSC 9;4 reports', () {
        TerminalProgress? report;
        terminal.onProgressReport = (value) => report = value;

        terminal.write(Uint8List.fromList('\x1b]9;4;1;42\x07'.codeUnits));

        expect(report, const TerminalProgress(state: .set, progress: 42));
      });

      test('maps omitted progress to null', () {
        TerminalProgress? report;
        terminal.onProgressReport = (value) => report = value;

        terminal.write(Uint8List.fromList('\x1b]9;4;3\x07'.codeUnits));

        expect(report, const TerminalProgress(state: .indeterminate));
      });
    });

    group('XT checksum options', () {
      test('enables reports and restores the default calculation', () {
        final output = <int>[];
        terminal.onWritePty = output.addAll;
        terminal.write(Uint8List.fromList('hello'.codeUnits));
        terminal.xtChecksumReport = true;
        terminal.xtChecksumExtension = 1;

        terminal.write(Uint8List.fromList('\x1b[1;1;1;1;1;5*y'.codeUnits));
        expect(output, Uint8List.fromList('\x1bP1!~0214\x1b\\'.codeUnits));

        output.clear();
        terminal.write(Uint8List.fromList('\x1b[0#y\x1bc'.codeUnits));
        terminal.write(Uint8List.fromList('hello'.codeUnits));
        terminal.write(Uint8List.fromList('\x1b[1;1;1;1;1;5*y'.codeUnits));
        expect(output, Uint8List.fromList('\x1bP1!~0214\x1b\\'.codeUnits));

        terminal.xtChecksumExtension = null;
        output.clear();
        terminal.write(Uint8List.fromList('\x1b[1;1;1;1;1;5*y'.codeUnits));
        expect(output, Uint8List.fromList('\x1bP1!~FDEC\x1b\\'.codeUnits));

        terminal.xtChecksumReport = false;
        output.clear();
        terminal.write(Uint8List.fromList('\x1b[1;1;1;1;1;5*y'.codeUnits));
        expect(output, isEmpty);
      });

      test('rejects checksum extension flags outside five bits', () {
        expect(() => terminal.xtChecksumExtension = 32, throwsRangeError);
      });
    });

    test('resize pull scrollback controls whether growth restores history', () {
      terminal.resize(cols: 5, rows: 3);
      terminal.resizePullScrollback = false;
      terminal.write(Uint8List.fromList('1\n2\n3\n4\n5'.codeUnits));
      terminal.resize(cols: 5, rows: 5);
      expect(terminal.scrollbackRows, greaterThan(0));

      terminal.resizePullScrollback = null;

      final defaultTerminal = Terminal(cols: 5, rows: 3);
      addTearDown(defaultTerminal.dispose);
      defaultTerminal.write(Uint8List.fromList('1\n2\n3\n4\n5'.codeUnits));
      defaultTerminal.resize(cols: 5, rows: 5);
      expect(defaultTerminal.scrollbackRows, 0);
    });

    group('terminal data', () {
      test('reports the current mouse shape', () {
        expect(terminal.mouseShape, MouseShape.text);

        terminal.write(Uint8List.fromList('\x1b]22;pointer\x07'.codeUnits));
        expect(terminal.mouseShape, MouseShape.pointer);

        terminal.write(Uint8List.fromList('\x1b]22;\x07'.codeUnits));
        expect(terminal.mouseShape, MouseShape.text);
      });

      test('reports coherent screen memory usage', () {
        final usage = terminal.memoryUsage;

        expect(usage.primaryPages, greaterThan(0));
        expect(
          usage.primaryVirtualBytes,
          greaterThanOrEqualTo(usage.primaryResidentBytes),
        );
        expect(
          usage.alternateVirtualBytes,
          greaterThanOrEqualTo(usage.alternateResidentBytes),
        );
      });
    });

    group('write', () {
      Object captureError(void Function() operation) {
        try {
          operation();
        } on Object catch (error) {
          return error;
        }
        fail('Expected operation to throw');
      }

      test('notifies listeners before rethrowing callback errors', () {
        final error = StateError('bell failed');
        var notifications = 0;
        terminal.onBell = () => throw error;
        terminal.addListener(() => notifications++);

        expect(
          () => terminal.write(Uint8List.fromList([0x07])),
          throwsA(same(error)),
        );

        expect(notifications, 1);
      });

      test('allows a write from a resize callback', () {
        var callbackCalled = false;
        terminal.onWritePty = (_) {
          callbackCalled = true;
          terminal.write(Uint8List.fromList([0x61]));
        };
        terminal.modeSet(const TerminalMode.inBandResize(), value: true);

        terminal.resize(cols: 100, rows: 40);

        expect(callbackCalled, isTrue);
      });

      test('rethrows PTY output callback errors', () {
        final error = StateError('output failed');
        terminal.onWritePty = (_) => throw error;

        expect(
          () => terminal.write(Uint8List.fromList('\x1b[5n'.codeUnits)),
          throwsA(same(error)),
        );
      });

      test('rethrows title change callback errors', () {
        final error = StateError('title failed');
        terminal.onTitleChanged = () => throw error;

        expect(
          () =>
              terminal.write(Uint8List.fromList('\x1b]0;Title\x07'.codeUnits)),
          throwsA(same(error)),
        );
      });

      test('rethrows working directory callback errors', () {
        final error = StateError('pwd failed');
        terminal.onPwdChanged = () => throw error;

        expect(
          () => terminal.write(
            Uint8List.fromList('\x1b]7;file:///tmp\x07'.codeUnits),
          ),
          throwsA(same(error)),
        );
      });

      test('rethrows enquiry callback errors', () {
        final error = StateError('enquiry failed');
        terminal.onEnquiry = () => throw error;

        expect(
          () => terminal.write(Uint8List.fromList([0x05])),
          throwsA(same(error)),
        );
      });

      test('rethrows version query callback errors', () {
        final error = StateError('version failed');
        terminal.onXtversion = () => throw error;

        expect(
          () => terminal.write(Uint8List.fromList('\x1b[>q'.codeUnits)),
          throwsA(same(error)),
        );
      });

      test('rethrows color scheme callback errors', () {
        final error = StateError('color scheme failed');
        terminal.onColorScheme = () => throw error;

        expect(
          () => terminal.write(Uint8List.fromList('\x1b[?996n'.codeUnits)),
          throwsA(same(error)),
        );
      });

      test('rethrows size query callback errors', () {
        final error = StateError('size failed');
        terminal.onSize = () => throw error;

        expect(
          () => terminal.write(Uint8List.fromList('\x1b[18t'.codeUnits)),
          throwsA(same(error)),
        );
      });

      test('rethrows device attributes callback errors', () {
        final error = StateError('device attributes failed');
        terminal.onDeviceAttributes = () => throw error;

        expect(
          () => terminal.write(Uint8List.fromList('\x1b[c'.codeUnits)),
          throwsA(same(error)),
        );
      });

      test('rethrows failures for each operation across terminals', () {
        final inner = Terminal(cols: 80, rows: 24);
        addTearDown(inner.dispose);
        final outerError = StateError('outer failure');
        final innerError = StateError('inner failure');
        Object? nestedError;
        terminal.onBell = () => throw outerError;
        terminal.onTitleChanged = () {
          nestedError = captureError(() => inner.resize(cols: 100, rows: 40));
        };
        inner.onWritePty = (_) => throw innerError;
        inner.modeSet(const TerminalMode.inBandResize(), value: true);

        final outerThrown = captureError(
          () => terminal.write(
            Uint8List.fromList('\x07\x1b]0;nested\x1b\\'.codeUnits),
          ),
        );

        expect(
          (outer: outerThrown, inner: nestedError),
          (outer: outerError, inner: innerError),
        );
      });

      test('rethrows failures for each operation on the same terminal', () {
        final outerError = StateError('outer failure');
        final innerError = StateError('inner failure');
        Object? nestedError;
        terminal.onBell = () => throw outerError;
        terminal.onTitleChanged = () {
          nestedError = captureError(
            () => terminal.resize(cols: 100, rows: 40),
          );
        };
        terminal.onWritePty = (_) => throw innerError;
        terminal.modeSet(const TerminalMode.inBandResize(), value: true);

        final outerThrown = captureError(
          () => terminal.write(
            Uint8List.fromList('\x07\x1b]0;nested\x1b\\'.codeUnits),
          ),
        );

        expect(
          (outer: outerThrown, inner: nestedError),
          (outer: outerError, inner: innerError),
        );
      });

      test('rethrows the first of multiple callback errors', () {
        final first = StateError('first failure');
        final second = StateError('second failure');
        final errors = [first, second].iterator;
        terminal.onBell = () {
          errors.moveNext();
          throw errors.current;
        };

        expect(
          () => terminal.write(Uint8List.fromList([0x07, 0x07])),
          throwsA(same(first)),
        );

        expect(errors.moveNext(), isFalse);
      });

      test('finishes terminal mutation before rethrowing', () {
        final error = StateError('bell failed');
        terminal.onBell = () => throw error;

        expect(
          () => terminal.write(Uint8List.fromList('A\x07B'.codeUnits)),
          throwsA(same(error)),
        );

        expect(readRowText(terminal, 0), startsWith('AB'));
      });

      test('keeps the terminal usable after a callback error', () {
        final error = StateError('bell failed');
        terminal.onBell = () => throw error;
        expect(
          () => terminal.write(Uint8List.fromList([0x07])),
          throwsA(same(error)),
        );

        terminal.onBell = null;
        terminal.write(Uint8List.fromList('ready'.codeUnits));

        expect(readRowText(terminal, 0), startsWith('ready'));
      });

      test('updates screen cells', () {
        terminal.write(Uint8List.fromList('Hello'.codeUnits));
        final h = readCellAt(terminal, 0, 0);
        expect(h.content, 'H');
        final o = readCellAt(terminal, 0, 4);
        expect(o.content, 'o');
      });

      test('applies SGR style to text', () {
        terminal.write(Uint8List.fromList('\x1b[1;31mBold Red'.codeUnits));
        final cell = readCellAt(terminal, 0, 0);
        expect(cell.content, 'B');
        expect(cell.style.bold, isTrue);
        expect(cell.foreground, isA<PaletteColor>());
      });

      test('decodes multi-byte UTF-8', () {
        terminal.write(Uint8List.fromList([0xC3, 0xA9]));
        final cell = readCellAt(terminal, 0, 0);
        expect(cell.content, '\u00E9');
      });

      test('decodes split UTF-8 across writes', () {
        terminal.write(Uint8List.fromList([0xC3]));
        terminal.write(Uint8List.fromList([0xA9]));
        final cell = readCellAt(terminal, 0, 0);
        expect(cell.content, '\u00E9');
      });

      test('updates row text content', () {
        terminal.write(Uint8List.fromList('Hello World'.codeUnits));
        final text = readRowText(terminal, 0);
        expect(text, startsWith('Hello World'));
      });

      test('handles CRLF line breaks', () {
        terminal.write(Uint8List.fromList('Line1\r\nLine2'.codeUnits));
        final cell00 = readCellAt(terminal, 0, 0);
        expect(cell00.content, 'L');
        final cell10 = readCellAt(terminal, 1, 0);
        expect(cell10.content, 'L');
        final row0 = readRowText(terminal, 0);
        expect(row0, startsWith('Line1'));
        final row1 = readRowText(terminal, 1);
        expect(row1, startsWith('Line2'));
      });

      test('sets wide character width on leading and trailing cells', () {
        terminal.write(
          Uint8List.fromList([0xE6, 0x97, 0xA5, ...('A'.codeUnits)]),
        );
        final cell0 = readCellAt(terminal, 0, 0);
        expect(cell0.wide, CellWidth.wide);
        final cell1 = readCellAt(terminal, 0, 1);
        expect(cell1.wide, CellWidth.spacerTail);
        final cell2 = readCellAt(terminal, 0, 2);
        expect(cell2.wide, CellWidth.narrow);
      });

      test('wraps long lines across rows', () {
        final t = Terminal(cols: 5, rows: 3);
        final rs = RenderState();
        addTearDown(rs.dispose);
        addTearDown(t.dispose);
        t.write(Uint8List.fromList('ABCDEFGH'.codeUnits));

        rs.update(t);
        final cellE = readCellAt(t, 0, 4);
        expect(cellE.content, 'E');
        expect(isRowWrapped(t, 0), isTrue);
        final cellF = readCellAt(t, 1, 0);
        expect(cellF.content, 'F');
        final cellH = readCellAt(t, 1, 2);
        expect(cellH.content, 'H');
        expect(isRowWrapped(t, 1), isFalse);
      });
    });

    group('modes', () {
      test('tracks default-off DEC private modes', () {
        expect(terminal.modeGet(const .cursorKeys()), isFalse);

        terminal.write(Uint8List.fromList('\x1b[?2004h'.codeUnits));
        expect(terminal.modeGet(const .bracketedPaste()), isTrue);

        terminal.write(Uint8List.fromList('\x1b[?2004l'.codeUnits));
        expect(terminal.modeGet(const .bracketedPaste()), isFalse);

        terminal.write(Uint8List.fromList('\x1b[?1h'.codeUnits));
        expect(terminal.modeGet(const .cursorKeys()), isTrue);

        terminal.write(Uint8List.fromList('\x1b[?1l'.codeUnits));
        expect(terminal.modeGet(const .cursorKeys()), isFalse);
      });

      test('tracks default-on DEC private modes', () {
        expect(terminal.modeGet(const .autoWrap()), isTrue);
        expect(terminal.modeGet(const .alternateScroll()), isTrue);

        terminal.write(Uint8List.fromList('\x1b[?7l'.codeUnits));
        expect(terminal.modeGet(const .autoWrap()), isFalse);

        terminal.write(Uint8List.fromList('\x1b[?7h'.codeUnits));
        expect(terminal.modeGet(const .autoWrap()), isTrue);

        terminal.write(Uint8List.fromList('\x1b[?1007l'.codeUnits));
        expect(terminal.modeGet(const .alternateScroll()), isFalse);

        terminal.write(Uint8List.fromList('\x1b[?1007h'.codeUnits));
        expect(terminal.modeGet(const .alternateScroll()), isTrue);
      });

      test('tracks ANSI modes', () {
        expect(terminal.modeGet(const .insert()), isFalse);

        terminal.write(Uint8List.fromList('\x1b[4h'.codeUnits));
        expect(terminal.modeGet(const .insert()), isTrue);

        terminal.write(Uint8List.fromList('\x1b[4l'.codeUnits));
        expect(terminal.modeGet(const .insert()), isFalse);
      });

      test('restores a configured default after reset', () {
        terminal.modeSetDefault(const .bracketedPaste(), value: true);
        terminal.modeSet(const .bracketedPaste(), value: false);

        terminal.reset();

        expect(terminal.modeGet(const .bracketedPaste()), isTrue);
      });

      group('mouseTracking', () {
        test('default is none', () {
          expect(terminal.mouseTracking, MouseTracking.none);
        });

        test('tracks DECSET tracking modes', () {
          terminal.write(Uint8List.fromList('\x1b[?9h'.codeUnits));
          expect(terminal.mouseTracking, MouseTracking.x10);

          terminal.write(Uint8List.fromList('\x1b[?1000h'.codeUnits));
          expect(terminal.mouseTracking, MouseTracking.normal);

          terminal.write(Uint8List.fromList('\x1b[?1002h'.codeUnits));
          expect(terminal.mouseTracking, MouseTracking.button);

          terminal.write(Uint8List.fromList('\x1b[?1003h'.codeUnits));
          expect(terminal.mouseTracking, MouseTracking.any);
        });

        test('DECRST disables mouse tracking', () {
          terminal.write(Uint8List.fromList('\x1b[?1000h'.codeUnits));
          expect(terminal.mouseTracking, MouseTracking.normal);

          terminal.write(Uint8List.fromList('\x1b[?1000l'.codeUnits));
          expect(terminal.mouseTracking, MouseTracking.none);
        });
      });
    });

    group('activeScreen', () {
      test('switches between primary and alternate screens', () {
        terminal.write(Uint8List.fromList('Primary'.codeUnits));
        terminal.write(Uint8List.fromList('\x1b[?1049h'.codeUnits));

        expect(terminal.activeScreen, TerminalScreen.alternate);
        final cell = readCellAt(terminal, 0, 0);
        expect(cell.isEmpty, isTrue);

        terminal.write(Uint8List.fromList('\x1b[?1049l'.codeUnits));

        expect(terminal.activeScreen, TerminalScreen.primary);
        final pCell = readCellAt(terminal, 0, 0);
        expect(pCell.content, 'P');
      });
    });

    group('isViewportActive', () {
      test('is true for the active area', () {
        expect(terminal.isViewportActive, isTrue);
      });

      test('is false after scrolling into history', () {
        final t = Terminal(cols: 5, rows: 2);
        addTearDown(t.dispose);
        t.write(Uint8List.fromList('one\r\ntwo\r\nthree'.codeUnits));

        t.scrollViewport(-1);

        expect(t.isViewportActive, isFalse);
      });
    });

    group('hasVtProcessingError', () {
      test('is false for a fresh terminal', () {
        expect(terminal.hasVtProcessingError, isFalse);
      });
    });

    group('listeners', () {
      test('notifies on write', () {
        var count = 0;
        terminal.addListener(() => count++);
        terminal.write(Uint8List.fromList('A'.codeUnits));
        expect(count, greaterThan(0));
      });

      test('notifies on resize', () {
        var count = 0;
        terminal.addListener(() => count++);
        terminal.resize(cols: 120, rows: 40);
        expect(count, 1);
      });
    });

    group('onPwdChanged', () {
      test('fires for OSC 7 pwd change', () {
        var count = 0;
        terminal.onPwdChanged = () => count++;

        terminal.write(Uint8List.fromList('\x1b]7;file:///tmp\x07'.codeUnits));

        expect(count, 1);
      });
    });

    group('compressionActivity', () {
      test('changes after terminal activity', () {
        final initial = terminal.compressionActivity;

        terminal.write(
          Uint8List.fromList(
            List.filled(
              4000,
              'compressible terminal history\r\n',
            ).join().codeUnits,
          ),
        );
        final current = terminal.compressionActivity;

        expect(current, isNot(initial));
      });
    });

    group('compress', () {
      test('reports unsupported full compression on Windows', () {
        final result = terminal.compress(mode: .full);

        expect(result, TerminalCompressionResult.unsupported);
      }, testOn: 'windows');

      test('completes full compression on supported targets', () {
        final result = terminal.compress(mode: .full);

        expect(result, TerminalCompressionResult.complete);
      }, testOn: 'linux || mac-os || android || ios');
    });

    group('onClipboardWrite', () {
      test('delivers decoded clipboard requests', () {
        ClipboardWrite? received;
        terminal.onClipboardWrite = (write) {
          received = write;
          return .success;
        };

        terminal.write(
          Uint8List.fromList('\x1b]52;c;aGVsbG8Ad29ybGQ=\x07'.codeUnits),
        );

        expect(
          received,
          isA<ClipboardWrite>()
              .having(
                (write) => write.location,
                'location',
                ClipboardLocation.standard,
              )
              .having(
                (write) => write.contents.single.mime,
                'MIME type',
                'text/plain',
              )
              .having((write) => write.contents.single.data, 'data', [
                104,
                101,
                108,
                108,
                111,
                0,
                119,
                111,
                114,
                108,
                100,
              ]),
        );
      });

      test('delivers clear requests without content', () {
        ClipboardWrite? received;
        terminal.onClipboardWrite = (write) {
          received = write;
          return .success;
        };

        terminal.write(Uint8List.fromList('\x1b]52;s;\x07'.codeUnits));

        expect(received?.contents, isEmpty);
      });

      test('delivers clipboard read requests and replies with content', () {
        ClipboardReadRequest? received;
        final output = <Uint8List>[];
        terminal.onWritePty = output.add;
        terminal.onClipboardRead = (read) {
          received = read;
          return ClipboardReadReply(
            result: .success,
            contents: [
              ClipboardContent(
                mime: 'text/plain',
                data: Uint8List.fromList('hello'.codeUnits),
              ),
            ],
          );
        };

        terminal.write(Uint8List.fromList('\x1b]52;c;?\x07'.codeUnits));

        expect(received?.location, ClipboardLocation.standard);
        expect(received?.mimes, ['text/plain']);
        expect(received?.list, isFalse);
        expect(output, hasLength(1));
        expect(utf8.decode(output.single), '\x1b]52;c;aGVsbG8=\x07');
      });

      test('uses the replacement callback', () {
        var first = 0;
        var second = 0;
        terminal.onClipboardWrite = (_) {
          first++;
          return .success;
        };
        terminal.onClipboardWrite = (_) {
          second++;
          return .success;
        };

        terminal.write(Uint8List.fromList('\x1b]52;c;aGVsbG8=\x07'.codeUnits));

        expect((first: first, second: second), (first: 0, second: 1));
      });

      test('stops delivery after callback removal', () {
        var count = 0;
        terminal.onClipboardWrite = (_) {
          count++;
          return .success;
        };
        terminal.onClipboardWrite = null;

        terminal.write(Uint8List.fromList('\x1b]52;c;aGVsbG8=\x07'.codeUnits));

        expect(count, 0);
      });

      test('rethrows callback exceptions', () {
        final error = StateError('clipboard failed');
        terminal.onClipboardWrite = (_) => throw error;

        expect(
          () => terminal.write(
            Uint8List.fromList('\x1b]52;c;aGVsbG8=\x07'.codeUnits),
          ),
          throwsA(same(error)),
        );
      });
    });

    group('clipboardWriteMaxBytes', () {
      test('gets, sets, and restores the clipboard limit', () {
        final defaultLimit = terminal.clipboardWriteMaxBytes;
        expect(defaultLimit, greaterThan(0));

        terminal.clipboardWriteMaxBytes = 1024;
        expect(terminal.clipboardWriteMaxBytes, 1024);

        terminal.clipboardWriteMaxBytes = null;
        expect(terminal.clipboardWriteMaxBytes, defaultLimit);
      });
    });

    group('paste', () {
      test('uses terminal paste policy and current mode', () {
        final output = <Uint8List>[];
        terminal.onWritePty = output.add;

        terminal.paste('hello');

        expect(utf8.decode(output.single), 'hello');
      });

      test('rejects unsafe text unless explicitly allowed', () {
        final output = <Uint8List>[];
        terminal.onWritePty = output.add;

        expect(
          () => terminal.paste('rm -rf /\n'),
          throwsA(isA<RejectedException>()),
        );
        expect(output, isEmpty);

        terminal.paste('rm -rf /\n', allowUnsafe: true);

        expect(utf8.decode(output.single), 'rm -rf /\r');
      });
    });

    group('resize', () {
      test('rethrows output callback errors', () {
        final error = StateError('resize output failed');
        terminal.onWritePty = (_) => throw error;
        terminal.modeSet(const TerminalMode.inBandResize(), value: true);

        expect(
          () => terminal.resize(cols: 100, rows: 40),
          throwsA(same(error)),
        );
      });

      test('updates dimensions before rethrowing output callback errors', () {
        final error = StateError('resize output failed');
        terminal.onWritePty = (_) => throw error;
        terminal.modeSet(const TerminalMode.inBandResize(), value: true);

        expect(
          () => terminal.resize(cols: 100, rows: 40),
          throwsA(same(error)),
        );

        expect(
          terminal.geometry,
          const TerminalGeometry(cols: 100, rows: 40, widthPx: 0, heightPx: 0),
        );
      });

      test('emits in-band size report when mode 2048 is enabled', () {
        Uint8List? received;
        terminal.onWritePty = (data) => received = data;
        terminal.modeSet(const TerminalMode.inBandResize(), value: true);

        terminal.resize(cols: 100, rows: 40, cellWidthPx: 9, cellHeightPx: 18);

        expect(String.fromCharCodes(received!), '\x1B[48;40;100;720;900t');
      });

      test('clamps cursor', () {
        final renderState = RenderState();
        addTearDown(renderState.dispose);
        terminal.write(Uint8List.fromList('\x1b[24;80H'.codeUnits));

        terminal.resize(cols: 40, rows: 10);
        renderState.update(terminal);

        expect(renderState.cursor.viewportY, lessThan(10));
        expect(renderState.cursor.viewportX, lessThan(40));
      });

      test('shrinking rows adjusts cursor position', () {
        final resizedTerminal = Terminal(cols: 10, rows: 5);
        final renderState = RenderState();
        addTearDown(renderState.dispose);
        addTearDown(resizedTerminal.dispose);
        resizedTerminal.write(
          Uint8List.fromList('A\r\nB\r\nC\r\nD\r\nE'.codeUnits),
        );
        renderState.update(resizedTerminal);

        resizedTerminal.resize(cols: 10, rows: 3);
        renderState.update(resizedTerminal);

        expect(renderState.cursor.viewportY, 2);
      });

      test('no content duplication after shrink', () {
        final t = Terminal(cols: 10, rows: 6);
        addTearDown(t.dispose);
        t.write(
          Uint8List.fromList(
            'Row_0\r\nRow_1\r\nRow_2\r\nRow_3\r\nRow_4\r\nRow_5\r\n'.codeUnits,
          ),
        );

        t.resize(cols: 10, rows: 3);

        expect(TerminalDump.hasContentOverlap(t), isFalse);
      });

      test('shrink-grow cycle preserves screen content', () {
        final t = Terminal(cols: 10, rows: 6);
        addTearDown(t.dispose);
        t.write(
          Uint8List.fromList(
            'AAA\r\nBBB\r\nCCC\r\nDDD\r\nEEE\r\nFFF'.codeUnits,
          ),
        );

        t.resize(cols: 10, rows: 3);
        final afterShrink = TerminalDump.screenContent(
          t,
        ).map((l) => l.trimRight()).where((l) => l.isNotEmpty).toList();

        t.resize(cols: 10, rows: 6);
        final afterGrow = TerminalDump.screenContent(
          t,
        ).map((l) => l.trimRight()).where((l) => l.isNotEmpty).toList();

        expect(afterGrow, containsAllInOrder(afterShrink));
      });

      test('multiple resize cycles maintain integrity', () {
        final t = Terminal(cols: 10, rows: 8);
        addTearDown(t.dispose);
        t.write(
          Uint8List.fromList(
            'Line0\r\nLine1\r\nLine2\r\nLine3\r\n'
                    'Line4\r\nLine5\r\nLine6\r\nLine7\r\n'
                .codeUnits,
          ),
        );

        t.resize(cols: 10, rows: 4);
        expect(TerminalDump.hasContentOverlap(t), isFalse);

        t.resize(cols: 10, rows: 6);
        expect(TerminalDump.hasContentOverlap(t), isFalse);

        t.resize(cols: 10, rows: 2);
        expect(TerminalDump.hasContentOverlap(t), isFalse);

        expect(TerminalDump.nonEmptyContent(t), ['Line7']);
      });

      test('column shrink preserves content within new width', () {
        final t = Terminal(cols: 10, rows: 3);
        addTearDown(t.dispose);
        t.write(Uint8List.fromList('ABCDEFGHIJ'.codeUnits));

        t.resize(cols: 5, rows: 3);
        final cellA = readCellAt(t, 0, 0);
        expect(cellA.content, 'A');
        final cellE = readCellAt(t, 0, 4);
        expect(cellE.content, 'E');
      });

      test('column grow pads with empty cells', () {
        final t = Terminal(cols: 5, rows: 3);
        addTearDown(t.dispose);
        t.write(Uint8List.fromList('ABCDE'.codeUnits));

        t.resize(cols: 10, rows: 3);
        final cellA = readCellAt(t, 0, 0);
        expect(cellA.content, 'A');
        final cellE = readCellAt(t, 0, 4);
        expect(cellE.content, 'E');
        final cell5 = readCellAt(t, 0, 5);
        expect(cell5.isEmpty, isTrue);
        final cell9 = readCellAt(t, 0, 9);
        expect(cell9.isEmpty, isTrue);
      });
    });

    group('screen', () {
      group('initialization', () {
        test('fresh terminal is clean', () {
          final t = Terminal(cols: 80, rows: 24);
          final rs = RenderState();
          addTearDown(rs.dispose);
          addTearDown(t.dispose);
          _expectAllCellsEmpty(t);
          rs.update(t);
          expect(rs.cursor.viewportY, 0);
          expect(rs.cursor.viewportX, 0);
        });

        test('multiple dispose-recreate cycles produce clean screens', () {
          final first = Terminal(cols: 40, rows: 10);
          _expectAllCellsEmpty(first);
          first.write(Uint8List.fromList('Cycle 1 data fill'.codeUnits));
          first.dispose();

          final second = Terminal(cols: 40, rows: 10);
          addTearDown(second.dispose);
          _expectAllCellsEmpty(second);
        });

        test(
          'recreated terminal with different dimensions has all empty cells',
          () {
            var t = Terminal(cols: 80, rows: 24);
            t.write(Uint8List.fromList('Fill the screen'.codeUnits));
            t.dispose();

            t = Terminal(cols: 120, rows: 40);
            addTearDown(t.dispose);
            _expectAllCellsEmpty(t);
          },
        );
      });

      group('multi-instance', () {
        test('concurrent terminals have independent state', () {
          final t1 = Terminal(cols: 80, rows: 24);
          addTearDown(t1.dispose);
          final t2 = Terminal(cols: 80, rows: 24);
          addTearDown(t2.dispose);

          t1.write(Uint8List.fromList('Terminal One'.codeUnits));
          final cell = readCellAt(t1, 0, 9);
          expect(cell.content, 'O');
          _expectAllCellsEmpty(t2);
        });

        test('disposing one terminal does not affect the other', () {
          final t1 = Terminal(cols: 80, rows: 24);
          final t2 = Terminal(cols: 80, rows: 24);
          addTearDown(t2.dispose);

          t2.write(Uint8List.fromList('Still alive'.codeUnits));
          t1.dispose();

          final cellS = readCellAt(t2, 0, 0);
          expect(cellS.content, 'S');
          t2.write(Uint8List.fromList('\r\nMore data'.codeUnits));
          final cellM = readCellAt(t2, 1, 0);
          expect(cellM.content, 'M');
        });
      });
    });

    group('onWritePty', () {
      test('retains response bytes after terminal disposal', () {
        Uint8List? output;
        terminal.onWritePty = (data) => output = data;
        terminal.write(Uint8List.fromList('\x1b[5n'.codeUnits));

        terminal.dispose();

        expect(output, [0x1b, 0x5b, 0x30, 0x6e]);
      });
    });

    group('setTitleReports', () {
      test('does not report titles by default', () {
        Uint8List? output;
        terminal.title = 'example';
        terminal.onWritePty = (data) => output = data;

        terminal.write(Uint8List.fromList('\x1b[21t'.codeUnits));

        expect(output, isNull);
      });

      test('writes the title when reports are enabled', () {
        Uint8List? output;
        terminal.title = 'example';
        terminal.onWritePty = (data) => output = data;
        terminal.setTitleReports(enabled: true);

        terminal.write(Uint8List.fromList('\x1b[21t'.codeUnits));

        expect(String.fromCharCodes(output!), contains('example'));
      });
    });

    group('onDeviceAttributes', () {
      String responseFor(
        String request,
        DeviceAttributesResponse Function() callback,
      ) {
        Uint8List? received;
        terminal.onWritePty = (data) => received = data;
        terminal.onDeviceAttributes = callback;
        terminal.write(Uint8List.fromList(request.codeUnits));
        expect(received, isNotNull);
        return String.fromCharCodes(received!);
      }

      test('sends configured responses', () {
        final primary = responseFor(
          '\x1b[c',
          () => const DeviceAttributesResponse(
            primary: DeviceAttributesPrimary(
              conformanceLevel: 65,
              features: [1, 6, 22],
            ),
          ),
        );
        expect(primary, contains('\x1b[?65;1;6;22c'));

        final secondary = responseFor(
          '\x1b[>c',
          () => const DeviceAttributesResponse(
            secondary: DeviceAttributesSecondary(
              deviceType: 41,
              firmwareVersion: 10,
            ),
          ),
        );
        expect(secondary, contains('\x1b[>41;10;0c'));

        final tertiary = responseFor(
          '\x1b[=c',
          () => const DeviceAttributesResponse(
            tertiary: DeviceAttributesTertiary(unitId: 42),
          ),
        );
        expect(tertiary, contains('!|0000002A'));
      });

      test('uses default response when unset', () {
        Uint8List? received;
        terminal.onWritePty = (data) => received = data;
        terminal.onDeviceAttributes = null;
        terminal.write(Uint8List.fromList('\x1b[c'.codeUnits));
        final response = String.fromCharCodes(received!);
        expect(response, contains('\x1b[?62'));
      });
    });

    group('Formatter', () {
      test('plain format returns screen content', () {
        terminal.write(Uint8List.fromList('Hello'.codeUnits));
        final formatter = Formatter(
          terminal: terminal,
          format: .plain,
          trim: true,
        );
        addTearDown(formatter.dispose);
        expect(formatter.format(), contains('Hello'));
      });

      test('selection restricts output to the given range', () {
        terminal.write(Uint8List.fromList('ABCDE\r\nFGHIJ'.codeUnits));
        final formatter = Formatter(
          terminal: terminal,
          format: .plain,
          selection: Selection.fromRefs(
            start: GridRef.at(terminal, const Position(row: 0, col: 0)),
            end: GridRef.at(terminal, const Position(row: 0, col: 2)),
          ),
        );
        addTearDown(formatter.dispose);
        final text = formatter.format();
        expect(text, contains('ABC'));
        expect(text, isNot(contains('FGHIJ')));
      });
    });

    group('formatSelection', () {
      test('returns null without an active selection', () {
        final text = terminal.formatSelection();

        expect(text, isNull);
      });

      test('formats an explicit selection', () {
        terminal.write(Uint8List.fromList('ABCDE'.codeUnits));
        final selection = Selection.fromRefs(
          start: GridRef.at(terminal, const Position(row: 0, col: 1)),
          end: GridRef.at(terminal, const Position(row: 0, col: 3)),
        );

        final text = terminal.formatSelection(selection: selection);

        expect(text, 'BCD');
      });
    });

    group('selectAll', () {
      test('selects all screen content', () {
        terminal.write(Uint8List.fromList('ABC\r\nDEF'.codeUnits));

        final selection = terminal.selectAll();

        expect(
          terminal.formatSelection(selection: selection, trim: true),
          'ABC\nDEF',
        );
      });
    });

    group('selectLine', () {
      test('selects the line under a ref', () {
        terminal.write(Uint8List.fromList('ABC\r\nDEF'.codeUnits));
        final ref = GridRef.at(terminal, const Position(row: 1, col: 1));

        final selection = terminal.selectLine(ref);

        expect(
          terminal.formatSelection(selection: selection, trim: true),
          'DEF',
        );
      });
    });

    group('selectOutput', () {
      test('selects command output under a ref', () {
        terminal.write(
          Uint8List.fromList(
            '\x1b]133;A\x07\$ \x1b]133;B\x07ls\r\n'
                    '\x1b]133;C\x07ABC\r\nDEF\x1b]133;D\x07'
                .codeUnits,
          ),
        );
        final ref = GridRef.at(terminal, const Position(row: 1, col: 1));

        final selection = terminal.selectOutput(ref);

        expect(
          terminal.formatSelection(selection: selection, trim: true),
          'ABC\nDEF',
        );
      });
    });

    group('selectWord', () {
      test('returns the selected word', () {
        terminal.write(Uint8List.fromList('hello world'.codeUnits));
        final ref = GridRef.at(terminal, const Position(row: 0, col: 1));

        final selection = terminal.selectWord(ref);

        expect(terminal.formatSelection(selection: selection), 'hello');
      });

      test('rejects refs from another terminal', () {
        final other = Terminal(cols: 80, rows: 24);
        addTearDown(other.dispose);
        final ref = GridRef.at(other, const Position(row: 0, col: 0));

        expect(() => terminal.selectWord(ref), throwsA(isA<ArgumentError>()));
      });
    });

    group('selectWordBetween', () {
      test('selects the word between two refs', () {
        terminal.write(Uint8List.fromList('hello world'.codeUnits));
        final start = GridRef.at(terminal, const Position(row: 0, col: 1));
        final end = GridRef.at(terminal, const Position(row: 0, col: 3));

        final selection = terminal.selectWordBetween(start, end);

        expect(terminal.formatSelection(selection: selection), 'hello');
      });
    });

    group('selection', () {
      test('setter installs active selection', () {
        terminal.write(Uint8List.fromList('ABCDE'.codeUnits));
        final selection = Selection.fromRefs(
          start: GridRef.at(terminal, const Position(row: 0, col: 0)),
          end: GridRef.at(terminal, const Position(row: 0, col: 2)),
        );

        terminal.selection = selection;

        expect(terminal.formatSelection(), 'ABC');
      });

      test('getter returns active selection', () {
        terminal.write(Uint8List.fromList('ABCDE'.codeUnits));
        final selection = Selection.fromRefs(
          start: GridRef.at(terminal, const Position(row: 0, col: 0)),
          end: GridRef.at(terminal, const Position(row: 0, col: 2)),
        );
        terminal.selection = selection;

        final active = terminal.selection;

        expect(active?.equal(selection), isTrue);
      });

      test('setter clears active selection', () {
        terminal.write(Uint8List.fromList('ABCDE'.codeUnits));
        terminal.selection = Selection.fromRefs(
          start: GridRef.at(terminal, const Position(row: 0, col: 0)),
          end: GridRef.at(terminal, const Position(row: 0, col: 2)),
        );

        terminal.selection = null;

        expect(terminal.selection, isNull);
      });

      test('setter rejects selections from another terminal', () {
        final other = Terminal(cols: 80, rows: 24);
        addTearDown(other.dispose);
        final selection = Selection.fromRefs(
          start: GridRef.at(other, const Position(row: 0, col: 0)),
          end: GridRef.at(other, const Position(row: 0, col: 2)),
        );

        expect(
          () => terminal.selection = selection,
          throwsA(isA<ArgumentError>()),
        );
      });
    });
  });
}

void _expectAllCellsEmpty(Terminal terminal) {
  final rs = RenderState();
  final rowIter = RowIterator();
  final cellIter = CellIterator();
  try {
    rs.update(terminal);
    rowIter.reset(rs);
    while (rowIter.next()) {
      cellIter.reset(rowIter);
      while (cellIter.next()) {
        expect(
          cellIter.hasText,
          isFalse,
          reason: 'cell at (${rowIter.index}, ${cellIter.col}) should be empty',
        );
      }
    }
  } finally {
    cellIter.dispose();
    rowIter.dispose();
    rs.dispose();
  }
}

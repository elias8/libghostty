@Tags(['ffi'])
library;

import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flterm/src/controller/terminal_controller.dart';
import 'package:flterm/src/foundation.dart';
import 'package:flterm/src/input/input_message.dart';
import 'package:flterm/src/interaction/selection_session.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart' hide KeyEvent;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TerminalController', () {
    late TerminalSession binding;
    late TerminalController controller;

    setUp(() {
      controller = TerminalController();
      binding = controller as TerminalSession;
    });

    tearDown(() => controller.dispose());

    final inputs = <TerminalController, ViewAttachment>{};

    ViewAttachment inputFor(TerminalController target) =>
        inputs.putIfAbsent(target, () {
          final attachment = ViewAttachment(target);
          addTearDown(() {
            attachment.dispose();
            inputs.remove(target);
          });
          return attachment;
        });

    void replaceController(TerminalConfig config) {
      controller.dispose();
      controller = TerminalController(config: config);
      binding = controller as TerminalSession;
    }

    TerminalSession access(TerminalController target) =>
        target as TerminalSession;

    void writeControllerUtf8(TerminalController controller, String text) {
      controller.write(Uint8List.fromList(utf8.encode(text)));
    }

    void writeTerminalUtf8(Terminal terminal, String text) {
      terminal.write(Uint8List.fromList(utf8.encode(text)));
    }

    void enableMouseTracking(
      TerminalController target, {
      String sequence = '\x1b[?1002h\x1b[?1006h',
      double devicePixelRatio = 1.0,
    }) {
      writeControllerUtf8(target, sequence);
      access(target).handleResize(
        SurfaceMeasurement(
          cols: 80,
          rows: 24,
          cellWidth: 8,
          cellHeight: 16,
          paddingLeft: 0,
          paddingRight: 0,
          paddingTop: 0,
          paddingBottom: 0,
          devicePixelRatio: devicePixelRatio,
        ),
      );
    }

    group('fromSnapshot', () {
      Terminal terminalWithHistory({int lineCount = 10000}) {
        final terminal = Terminal(cols: 16, rows: 2)
          ..scrollbackMaxBytes = null
          ..scrollbackMaxLines = null;
        addTearDown(terminal.dispose);
        terminal.write(
          utf8.encode(
            List.generate(lineCount, (index) => 'line$index').join('\r\n'),
          ),
        );
        return terminal;
      }

      TerminalController restore(
        Terminal source, {
        bool progressive = true,
        bool deferResize = true,
      }) {
        final restored = TerminalController.fromSnapshot(
          source.encodeSnapshot(),
          progressive: progressive,
          deferResize: deferResize,
        );
        addTearDown(restored.dispose);
        return restored;
      }

      SurfaceMeasurement measurement(int cols, int rows) {
        return SurfaceMeasurement(
          cols: cols,
          rows: rows,
          cellWidth: 8,
          cellHeight: 16,
          paddingLeft: 0,
          paddingRight: 0,
          paddingTop: 0,
          paddingBottom: 0,
          devicePixelRatio: 1,
        );
      }

      group('validation', () {
        test('rejects a malformed snapshot prefix', () {
          final bytes = Uint8List.fromList([1, 2, 3]);

          expect(
            () => TerminalController.fromSnapshot(bytes),
            throwsA(isA<InvalidValueException>()),
          );
        });

        test('rejects a continuation limit below zero', () {
          expect(
            () => TerminalController.fromSnapshot(
              Uint8List(0),
              maxContinuationBytes: -1,
            ),
            throwsRangeError,
          );
        });

        test('rejects a continuation limit above the uint32 maximum', () {
          expect(
            () => TerminalController.fromSnapshot(
              Uint8List(0),
              maxContinuationBytes: 0x100000000,
            ),
            throwsRangeError,
          );
        });
      });

      group('synchronous restoration', () {
        test('reports complete restoration state before returning', () {
          final source = Terminal(cols: 16, rows: 2);
          addTearDown(source.dispose);

          final restored = restore(source, progressive: false);

          expect(restored.restoration, RestorationState.complete);
        });

        test('restores terminal content before returning', () {
          final source = Terminal(cols: 16, rows: 2);
          addTearDown(source.dispose);
          source.write(utf8.encode('restored'));

          final restored = restore(source, progressive: false);
          final formatter = restored.createFormatter(format: .plain);
          addTearDown(formatter.dispose);

          expect(formatter.format(), startsWith('restored'));
        });

        test('completes restored before returning', () async {
          final source = Terminal(cols: 16, rows: 2);
          addTearDown(source.dispose);

          final restored = restore(source, progressive: false);

          await expectLater(restored.restored, completes);
        });
      });

      group('progressive restoration', () {
        test('reports restoring while older scrollback is pending', () {
          final source = terminalWithHistory();

          final restored = restore(source);

          expect(restored.restoration, RestorationState.restoring);
        });

        test('returns with older scrollback still pending', () {
          final source = terminalWithHistory();

          final restored = restore(source);

          expect(restored.scrollbackRows, lessThan(source.scrollbackRows));
        });

        test('loads remaining scrollback automatically', () {
          fakeAsync((async) {
            final source = terminalWithHistory();
            final restored = restore(source);

            async.elapse(const Duration(seconds: 1));

            expect(restored.scrollbackRows, source.scrollbackRows);
          });
        });

        test('reports complete after loading history', () {
          fakeAsync((async) {
            final source = terminalWithHistory();
            final restored = restore(source);

            async.elapse(const Duration(seconds: 1));

            expect(restored.restoration, RestorationState.complete);
          });
        });

        test('notifies listeners when restoration completes', () {
          fakeAsync((async) {
            final source = terminalWithHistory();
            final restored = restore(source);
            final states = <RestorationState>[];
            restored.addListener(() => states.add(restored.restoration));

            async.elapse(const Duration(seconds: 1));

            expect(states, contains(RestorationState.complete));
          });
        });

        test('completes restored after loading history', () {
          fakeAsync((async) {
            final source = terminalWithHistory();
            final restored = restore(source);
            var completed = false;
            restored.restored.then<void>((_) => completed = true).ignore();

            async.elapse(const Duration(seconds: 1));
            async.flushMicrotasks();

            expect(completed, isTrue);
          });
        });

        test('copies the source bytes', () {
          fakeAsync((async) {
            final source = terminalWithHistory();
            final bytes = source.encodeSnapshot();
            final restored = TerminalController.fromSnapshot(bytes);
            addTearDown(restored.dispose);
            bytes.fillRange(0, bytes.length, 0);

            async.elapse(const Duration(seconds: 1));

            expect(restored.scrollbackRows, source.scrollbackRows);
          });
        });

        test('refreshes an active search as history arrives', () {
          fakeAsync((async) {
            final source = terminalWithHistory();
            final restored = restore(source);
            restored.search.search('line');
            async.elapse(Duration.zero);

            async.elapse(const Duration(seconds: 1));

            expect(restored.search.totalMatches, 10000);
          });
        });

        test('preserves live output while history arrives', () {
          fakeAsync((async) {
            final source = terminalWithHistory();
            final restored = restore(source);
            final output = utf8.encode('\r\nlive output');
            source.write(output);

            restored.write(output);
            async.elapse(const Duration(seconds: 1));

            final expected = Formatter(terminal: source, format: .plain);
            addTearDown(expected.dispose);
            final actual = restored.createFormatter(format: .plain);
            addTearDown(actual.dispose);
            expect(actual.format(), expected.format());
          });
        });
      });

      group('failure', () {
        TerminalController restoreDamaged() {
          final source = terminalWithHistory();
          final bytes = source.encodeSnapshot()..last ^= 0xff;
          final restored = TerminalController.fromSnapshot(bytes);
          addTearDown(restored.dispose);
          return restored;
        }

        test('reports failed after a late decoding error', () {
          fakeAsync((async) {
            final restored = restoreDamaged();

            async.elapse(const Duration(seconds: 1));

            expect(restored.restoration, RestorationState.failed);
          });
        });

        test('notifies listeners when restoration fails', () {
          fakeAsync((async) {
            final restored = restoreDamaged();
            final states = <RestorationState>[];
            restored.addListener(() => states.add(restored.restoration));

            async.elapse(const Duration(seconds: 1));

            expect(states, contains(RestorationState.failed));
          });
        });

        test('reports a late decoding error through restored', () {
          fakeAsync((async) {
            final restored = restoreDamaged();
            Object? failure;
            restored.restored
                .then<void>(
                  (_) {},
                  onError: (Object error, StackTrace _) => failure = error,
                )
                .ignore();

            async.elapse(const Duration(seconds: 1));
            async.flushMicrotasks();

            expect(failure, isA<InvalidValueException>());
          });
        });

        test('keeps the terminal usable after a late decoding error', () {
          fakeAsync((async) {
            final restored = restoreDamaged();

            async.elapse(const Duration(seconds: 1));

            expect(
              () => restored.write(utf8.encode('still usable')),
              returnsNormally,
            );
          });
        });

        test('reports disposal during restoration through restored', () {
          fakeAsync((async) {
            final source = terminalWithHistory();
            final restored = restore(source);
            Object? failure;
            restored.restored
                .then<void>(
                  (_) {},
                  onError: (Object error, StackTrace _) => failure = error,
                )
                .ignore();

            restored.dispose();
            async.flushMicrotasks();

            expect(failure, isA<StateError>());
          });
        });

        test('reports a deferred resize callback error through restored', () {
          fakeAsync((async) {
            final source = terminalWithHistory()
              ..modeSet(const .inBandResize(), value: true);
            final restored = restore(source);
            access(restored).handleResize(measurement(80, 24));
            restored.onOutput = (_) {
              throw StateError('resize callback failed');
            };
            Object? failure;
            restored.restored
                .then<void>(
                  (_) {},
                  onError: (Object error, StackTrace _) => failure = error,
                )
                .ignore();

            async.elapse(const Duration(seconds: 1));
            async.flushMicrotasks();

            expect(failure, isA<StateError>());
          });
        });
      });

      group('terminal state', () {
        test('preserves restored modes after leaving the alternate screen', () {
          final source = Terminal(cols: 16, rows: 2);
          addTearDown(source.dispose);
          source.write(utf8.encode('\x1b[?7lprimary\x1b[?1049halternate'));
          final restored = restore(source, progressive: false);

          restored.write(utf8.encode('\x1b[?1049l'));

          expect(restored.modeGet(const .autoWrap()), isFalse);
        });

        test('exposes the restored working directory immediately', () {
          final source = Terminal(cols: 16, rows: 2)
            ..pwd = 'file:///tmp/session';
          addTearDown(source.dispose);

          final restored = restore(source, progressive: false);

          expect(restored.pwd, 'file:///tmp/session');
        });
      });

      group('continuation', () {
        test('resumes a split UTF-8 character', () {
          final source = TerminalController(
            config: const TerminalConfig(continuationMaxBytes: 1024),
          );
          addTearDown(source.dispose);
          source.write(Uint8List.fromList([0xe7, 0x95]));
          final restored = TerminalController.fromSnapshot(
            source.snapshot(),
            progressive: false,
          );
          addTearDown(restored.dispose);

          restored.write(Uint8List.fromList([0x8c]));

          final formatter = restored.createFormatter(format: .plain);
          addTearDown(formatter.dispose);
          expect(formatter.format(), startsWith('界'));
        });

        test('retains unfinished input when requested', () {
          final source = TerminalController(
            config: const TerminalConfig(continuationMaxBytes: 1024),
          );
          addTearDown(source.dispose);
          source.write(utf8.encode('\x1b['));
          final restored = TerminalController.fromSnapshot(
            source.snapshot(),
            progressive: false,
            retainContinuation: true,
            maxContinuationBytes: 1024,
          );
          addTearDown(restored.dispose);

          final decoder = SnapshotDecoder(
            restored.snapshot(),
            retainContinuation: true,
          );
          addTearDown(decoder.dispose);
          final terminal = decoder.decode();
          addTearDown(terminal.dispose);

          expect(terminal.continuation, utf8.encode('\x1b['));
        });

        test('stops continuation tracking by default', () {
          final source = TerminalController(
            config: const TerminalConfig(continuationMaxBytes: 1024),
          );
          addTearDown(source.dispose);
          source.write(utf8.encode('\x1b['));
          final restored = TerminalController.fromSnapshot(
            source.snapshot(),
            progressive: false,
          );
          addTearDown(restored.dispose);

          expect(restored.snapshot, throwsA(isA<InvalidValueException>()));
        });

        test('rejects unfinished input above the decoder limit', () {
          final source = TerminalController(
            config: const TerminalConfig(continuationMaxBytes: 1024),
          );
          addTearDown(source.dispose);
          source.write(utf8.encode('\x1b['));
          final bytes = source.snapshot();

          expect(
            () =>
                TerminalController.fromSnapshot(bytes, maxContinuationBytes: 0),
            throwsA(isA<LimitExceededException>()),
          );
        });
      });

      group('deferred resize', () {
        test('defers backend resize reports while history loads', () {
          final restored = restore(terminalWithHistory());
          final sizes = <(int, int)>[];
          restored.onResize = (cols, rows) => sizes.add((cols, rows));

          access(restored).handleResize(measurement(80, 24));

          expect(sizes, isEmpty);
        });

        test('commits only the latest measurement after restoration', () {
          fakeAsync((async) {
            final restored = restore(terminalWithHistory());
            final sizes = <(int, int)>[];
            restored.onResize = (cols, rows) => sizes.add((cols, rows));
            access(restored).handleResize(measurement(80, 24));
            access(restored).handleResize(measurement(100, 30));

            async.elapse(const Duration(seconds: 1));

            expect(sizes, [(100, 30)]);
          });
        });

        test('allows resize to skip incompatible history when requested', () {
          fakeAsync((async) {
            final source = terminalWithHistory();
            final restored = restore(source, deferResize: false);

            access(restored).handleResize(measurement(80, 24));
            async.elapse(const Duration(seconds: 1));

            expect(restored.scrollbackRows, lessThan(source.scrollbackRows));
          });
        });

        test('keeps completion when the resize callback disposes', () {
          fakeAsync((async) {
            final restored = restore(terminalWithHistory());
            var completed = false;
            restored.onResize = (cols, rows) => restored.dispose();
            access(restored).handleResize(measurement(80, 24));
            restored.restored.then<void>((_) => completed = true).ignore();

            async.elapse(const Duration(seconds: 1));
            async.flushMicrotasks();

            expect(completed, isTrue);
          });
        });
      });
    });

    group('snapshot', () {
      test('rejects unfinished input without prior tracking', () {
        controller.write(utf8.encode('\x1b['));

        expect(controller.snapshot, throwsA(isA<InvalidValueException>()));
      });

      test('captures only scrollback that is currently loaded', () {
        final source = Terminal(cols: 16, rows: 2)..scrollbackMaxBytes = null;
        addTearDown(source.dispose);
        source.write(
          utf8.encode(
            List.generate(10000, (index) => 'line$index').join('\r\n'),
          ),
        );
        final restored = TerminalController.fromSnapshot(
          source.encodeSnapshot(),
        );
        addTearDown(restored.dispose);
        final loadedRows = restored.scrollbackRows;

        final decoder = SnapshotDecoder(restored.snapshot());
        addTearDown(decoder.dispose);
        final decoded = decoder.decode();
        addTearDown(decoded.dispose);

        expect(decoded.scrollbackRows, loadedRows);
      });

      test('produces a libghostty-compatible snapshot', () {
        controller.write(utf8.encode('saved terminal'));

        final decoder = SnapshotDecoder(controller.snapshot());
        addTearDown(decoder.dispose);
        final terminal = decoder.decode();
        addTearDown(terminal.dispose);
        final formatter = Formatter(terminal: terminal, format: .plain);
        addTearDown(formatter.dispose);

        expect(formatter.format(), startsWith('saved terminal'));
      });
    });

    group('constructor', () {
      test('has no restoration state for an ordinary controller', () {
        expect(controller.restoration, RestorationState.none);
      });

      test('is already restored for an ordinary controller', () async {
        await expectLater(controller.restored, completes);
      });

      test('exposes terminal state without a view attachment', () {
        expect(binding.terminal, isA<Terminal>());
      });

      test('starts without selection or selected text', () {
        expect(controller.hasSelection, isFalse);
        expect(controller.selectedText(), '');
      });
    });

    group('geometry', () {
      SurfaceMeasurement measurement(int cols, int rows) => SurfaceMeasurement(
        cols: cols,
        rows: rows,
        cellWidth: 8,
        cellHeight: 16,
        paddingLeft: 0,
        paddingRight: 0,
        paddingTop: 0,
        paddingBottom: 0,
        devicePixelRatio: 1,
      );

      test('does not notify a resize observer before view geometry exists', () {
        final sizes = <({int cols, int rows})>[];

        controller.onResize = (cols, rows) {
          sizes.add((cols: cols, rows: rows));
        };

        expect(sizes, isEmpty);
      });

      test('reports the first measured grid to the backend', () {
        final sizes = <({int cols, int rows})>[];
        controller.onResize = (cols, rows) {
          sizes.add((cols: cols, rows: rows));
        };

        binding.handleResize(
          const SurfaceMeasurement(
            cols: 80,
            rows: 24,
            cellWidth: 8,
            cellHeight: 16,
            paddingLeft: 0,
            paddingRight: 0,
            paddingTop: 0,
            paddingBottom: 0,
            devicePixelRatio: 1,
          ),
        );

        expect(sizes, [(cols: 80, rows: 24)]);
      });

      test(
        'reports committed grid when observer is assigned after measurement',
        () {
          binding.handleResize(
            const SurfaceMeasurement(
              cols: 100,
              rows: 40,
              cellWidth: 8,
              cellHeight: 16,
              paddingLeft: 0,
              paddingRight: 0,
              paddingTop: 0,
              paddingBottom: 0,
              devicePixelRatio: 1,
            ),
          );

          final sizes = <({int cols, int rows})>[];
          controller.onResize = (cols, rows) {
            sizes.add((cols: cols, rows: rows));
          };

          expect(sizes, [(cols: 100, rows: 40)]);
        },
      );

      test('resize callback observes committed physical geometry', () {
        final binding = access(controller);
        final output = <Uint8List>[];
        controller.onOutput = output.add;
        controller.onResize = (_, _) {
          controller.write(Uint8List.fromList(utf8.encode('\x1b[14t')));
        };

        binding.handleResize(
          const SurfaceMeasurement(
            cols: 80,
            rows: 24,
            cellWidth: 8,
            cellHeight: 16,
            paddingLeft: 0,
            paddingRight: 0,
            paddingTop: 0,
            paddingBottom: 0,
            devicePixelRatio: 1,
          ),
        );

        expect(utf8.decode(output.single), '\x1b[4;384;640t');
      });

      test('answers size queries without consuming render dirtiness', () {
        final renderState = RenderState();
        addTearDown(renderState.dispose);

        controller.write(Uint8List.fromList(utf8.encode('hello')));
        controller.write(Uint8List.fromList(utf8.encode('\x1b[18t')));

        renderState.update(binding.terminal);

        expect(renderState.dirty, isNot(DirtyState.clean));
      });

      test('reports configured dimensions before the first view layout', () {
        final custom = TerminalController(
          config: const TerminalConfig(cols: 120, rows: 40),
        );
        addTearDown(custom.dispose);
        final output = <Uint8List>[];
        custom.onOutput = output.add;

        custom.write(Uint8List.fromList(utf8.encode('\x1b[18t')));

        expect(utf8.decode(output.single), '\x1b[8;40;120t');
      });

      test('applies physical geometry through the resize event', () {
        binding.handleResize(
          const SurfaceMeasurement(
            cols: 80,
            rows: 24,
            cellWidth: 8,
            cellHeight: 16,
            paddingLeft: 0,
            paddingRight: 0,
            paddingTop: 0,
            paddingBottom: 0,
            devicePixelRatio: 2,
          ),
        );

        expect(
          binding.terminal.geometry,
          const TerminalGeometry(
            cols: 80,
            rows: 24,
            widthPx: 1280,
            heightPx: 768,
          ),
        );
      });

      test('updates physical geometry when the grid is unchanged', () {
        final binding = access(controller);
        binding.handleResize(
          const SurfaceMeasurement(
            cols: 80,
            rows: 24,
            cellWidth: 8,
            cellHeight: 16,
            paddingLeft: 0,
            paddingRight: 0,
            paddingTop: 0,
            paddingBottom: 0,
            devicePixelRatio: 1,
          ),
        );
        binding.handleResize(
          const SurfaceMeasurement(
            cols: 80,
            rows: 24,
            cellWidth: 10,
            cellHeight: 20,
            paddingLeft: 0,
            paddingRight: 0,
            paddingTop: 0,
            paddingBottom: 0,
            devicePixelRatio: 1,
          ),
        );

        expect(
          binding.terminal.geometry,
          const TerminalGeometry(
            cols: 80,
            rows: 24,
            widthPx: 800,
            heightPx: 480,
          ),
        );
      });

      test('ignores resize events with invalid physical geometry', () {
        final binding = access(controller);
        binding.handleResize(
          const SurfaceMeasurement(
            cols: 80,
            rows: 24,
            cellWidth: 8,
            cellHeight: 16,
            paddingLeft: 0,
            paddingRight: 0,
            paddingTop: 0,
            paddingBottom: 0,
            devicePixelRatio: 1,
          ),
        );

        binding.handleResize(
          const SurfaceMeasurement(
            cols: 100,
            rows: 30,
            cellWidth: 0,
            cellHeight: 16,
            paddingLeft: 0,
            paddingRight: 0,
            paddingTop: 0,
            paddingBottom: 0,
            devicePixelRatio: 1,
          ),
        );

        expect(
          binding.terminal.geometry,
          const TerminalGeometry(
            cols: 80,
            rows: 24,
            widthPx: 640,
            heightPx: 384,
          ),
        );
      });

      test('ignores resize events beyond the native grid limit', () {
        final binding = access(controller);

        binding.handleResize(
          const SurfaceMeasurement(
            cols: 80,
            rows: 24,
            cellWidth: 8,
            cellHeight: 16,
            paddingLeft: 0,
            paddingRight: 0,
            paddingTop: 0,
            paddingBottom: 0,
            devicePixelRatio: 1,
          ),
        );

        binding.handleResize(
          const SurfaceMeasurement(
            cols: 65536,
            rows: 24,
            cellWidth: 8,
            cellHeight: 16,
            paddingLeft: 0,
            paddingRight: 0,
            paddingTop: 0,
            paddingBottom: 0,
            devicePixelRatio: 1,
          ),
        );

        expect(
          binding.terminal.geometry,
          const TerminalGeometry(
            cols: 80,
            rows: 24,
            widthPx: 640,
            heightPx: 384,
          ),
        );
      });

      test('emits the measured in-band resize report', () {
        final binding = access(controller);
        final output = <Uint8List>[];
        controller.onOutput = output.add;
        binding.terminal.modeSet(
          const TerminalMode.inBandResize(),
          value: true,
        );

        binding.handleResize(
          const SurfaceMeasurement(
            cols: 80,
            rows: 24,
            cellWidth: 8,
            cellHeight: 16,
            paddingLeft: 0,
            paddingRight: 0,
            paddingTop: 0,
            paddingBottom: 0,
            devicePixelRatio: 1,
          ),
        );

        expect(utf8.decode(output.single), '\x1B[48;24;80;384;640t');
      });

      test('resize callback observes committed mouse geometry', () {
        writeControllerUtf8(controller, '\x1b[?1000h\x1b[?1016h');
        final output = <Uint8List>[];
        controller.onOutput = output.add;
        controller.onResize = (_, _) {
          inputFor(binding).onMouseInput(
            const MouseInput(
              action: .press,
              anyButtonPressed: true,
              button: .left,
              mods: Mods.none(),
              pixelX: 4,
              pixelY: 8,
            ),
          );
        };

        binding.handleResize(
          const SurfaceMeasurement(
            cols: 80,
            rows: 24,
            cellWidth: 8,
            cellHeight: 16,
            paddingLeft: 0,
            paddingRight: 0,
            paddingTop: 0,
            paddingBottom: 0,
            devicePixelRatio: 2,
          ),
        );

        expect(utf8.decode(output.single), '\x1b[<0;8;16M');
      });

      test('resize callback observes committed selection geometry', () {
        controller.write(Uint8List.fromList(utf8.encode('hello')));
        final viewToken = binding.attachView();
        addTearDown(() => binding.detachView(viewToken));
        final selectionInput = binding.createSelectionInteraction();
        addTearDown(selectionInput.dispose);
        var selected = false;
        controller.onResize = (_, _) {
          selectionInput.handlePress(
            const SelectionPressInput(
              pixelX: 8,
              pixelY: 0,
              behaviors: SelectionGestureBehaviors.standard,
              wordBoundaries: null,
              repeatDistance: 18,
              repeatInterval: Duration(milliseconds: 300),
              timeStamp: Duration.zero,
              fullWidthLine: false,
            ),
          );
          selectionInput.handleDrag(
            const SelectionPointerInput(
              pixelX: 16,
              pixelY: 0,
              rectangle: false,
            ),
          );
          selectionInput.handleRelease(const Position(row: 0, col: 1));
          selected = controller.hasSelection;
        };

        binding.handleResize(
          const SurfaceMeasurement(
            cols: 80,
            rows: 24,
            cellWidth: 8,
            cellHeight: 16,
            paddingLeft: 0,
            paddingRight: 0,
            paddingTop: 0,
            paddingBottom: 0,
            devicePixelRatio: 1,
          ),
        );

        expect(selected, isTrue);
      });

      test('emits terminal resize output before the backend callback', () {
        final binding = access(controller);
        final events = <String>[];
        controller.onResize = (_, _) => events.add('resize');
        events.clear();
        controller.onOutput = (_) => events.add('output');
        binding.terminal.modeSet(
          const TerminalMode.inBandResize(),
          value: true,
        );

        binding.handleResize(
          const SurfaceMeasurement(
            cols: 81,
            rows: 24,
            cellWidth: 8,
            cellHeight: 16,
            paddingLeft: 0,
            paddingRight: 0,
            paddingTop: 0,
            paddingBottom: 0,
            devicePixelRatio: 1,
          ),
        );

        expect(events, ['output', 'resize']);
      });

      test('publishes reentrant changes after geometry is committed', () {
        binding.handleResize(measurement(80, 24));
        controller.modeSet(const TerminalMode.inBandResize(), value: true);
        int? observedColumns;
        controller.addListener(() {
          observedColumns = binding.committedGeometry?.cols;
        });
        controller.onOutput = (_) => controller.toggleMod(const Mods.ctrl());

        binding.handleResize(measurement(81, 25));

        expect(observedColumns, 81);
      });

      test('retains the latest reentrant geometry transaction', () {
        binding.handleResize(measurement(80, 24));
        controller.modeSet(const TerminalMode.inBandResize(), value: true);
        controller.onOutput = (_) {
          controller.onOutput = null;
          binding.handleResize(measurement(100, 30));
        };

        binding.handleResize(measurement(81, 25));

        expect(binding.committedGeometry?.cols, 100);
      });

      test('allows backend output during an in-band resize report', () {
        final binding = access(controller);
        var replied = false;
        controller.onOutput = (_) {
          replied = true;
          controller.write(Uint8List.fromList(utf8.encode('nested')));
        };
        binding.terminal.modeSet(
          const TerminalMode.inBandResize(),
          value: true,
        );

        binding.handleResize(
          const SurfaceMeasurement(
            cols: 81,
            rows: 24,
            cellWidth: 8,
            cellHeight: 16,
            paddingLeft: 0,
            paddingRight: 0,
            paddingTop: 0,
            paddingBottom: 0,
            devicePixelRatio: 1,
          ),
        );

        expect(replied, isTrue);
      });
    });

    group('handleMouseEvent', () {
      test('clears a previous button for buttonless motion', () {
        enableMouseTracking(controller, sequence: '\x1b[?1003h\x1b[?1006h');
        final output = <Uint8List>[];
        controller.onOutput = output.add;

        inputFor(binding).onMouseInput(
          const MouseInput(
            action: .press,
            anyButtonPressed: true,
            button: .right,
            mods: Mods.none(),
            pixelX: 4,
            pixelY: 8,
          ),
        );
        inputFor(binding).onMouseInput(
          const MouseInput(
            action: .motion,
            anyButtonPressed: false,
            button: null,
            mods: Mods.none(),
            pixelX: 4,
            pixelY: 8,
          ),
        );

        expect(output, hasLength(2));
        expect(utf8.decode(output.last), startsWith('\x1b[<35;'));
      });

      test('passes aggregate pressed state to the encoder', () {
        enableMouseTracking(controller);
        final output = <Uint8List>[];
        controller.onOutput = output.add;

        inputFor(binding).onMouseInput(
          const MouseInput(
            action: .motion,
            anyButtonPressed: false,
            button: .left,
            mods: Mods.none(),
            pixelX: 1000,
            pixelY: 1000,
          ),
        );

        inputFor(binding).onMouseInput(
          const MouseInput(
            action: .motion,
            anyButtonPressed: true,
            button: .left,
            mods: Mods.none(),
            pixelX: 1000,
            pixelY: 1000,
          ),
        );

        expect(output, hasLength(1));
      });

      test('applies device pixel ratio once to SGR pixel coordinates', () {
        enableMouseTracking(
          controller,
          sequence: '\x1b[?1000h\x1b[?1016h',
          devicePixelRatio: 2,
        );
        final output = <Uint8List>[];
        controller.onOutput = output.add;

        inputFor(binding).onMouseInput(
          const MouseInput(
            action: .press,
            anyButtonPressed: true,
            button: .left,
            mods: Mods.none(),
            pixelX: 4,
            pixelY: 8,
          ),
        );

        expect(utf8.decode(output.single), '\x1b[<0;8;16M');
      });

      test(
        'maps terminal-local pointer coordinates through surface padding',
        () {
          enableMouseTracking(controller, sequence: '\x1b[?1000h\x1b[?1016h');
          binding.handleResize(
            const SurfaceMeasurement(
              cols: 80,
              rows: 24,
              cellWidth: 8,
              cellHeight: 16,
              paddingLeft: 8,
              paddingRight: 4,
              paddingTop: 6,
              paddingBottom: 2,
              devicePixelRatio: 1,
            ),
          );
          final output = <Uint8List>[];
          controller.onOutput = output.add;

          inputFor(binding).onMouseInput(
            const MouseInput(
              action: .press,
              anyButtonPressed: true,
              button: .left,
              mods: Mods.none(),
              pixelX: 4,
              pixelY: 8,
            ),
          );

          expect(utf8.decode(output.single), '\x1b[<0;4;8M');
        },
      );
    });

    group('handleTerminalScroll', () {
      test('uses the last pointer position for tracked scroll', () {
        enableMouseTracking(controller);
        binding.terminal.write(Uint8List.fromList(utf8.encode('\x1b[?1049h')));
        final output = <Uint8List>[];
        controller.onOutput = output.add;

        inputFor(binding).onScrollInput(
          const ScrollInput(
            horizontal: 0,
            mods: Mods.none(),
            pixelX: 24,
            pixelY: 16,
            reportMouse: true,
            vertical: -1,
          ),
        );

        expect(utf8.decode(output.single), '\x1b[<64;4;2M');
      });

      test('batches repeated tracked scroll reports', () {
        enableMouseTracking(controller);
        final output = <Uint8List>[];
        controller.onOutput = output.add;

        inputFor(binding).onScrollInput(
          const ScrollInput(
            horizontal: 0,
            mods: Mods.none(),
            pixelX: 24,
            pixelY: 16,
            reportMouse: true,
            vertical: -3,
          ),
        );

        expect(output, hasLength(1));
      });

      test(
        'does not simulate cursor keys when alternate scroll is disabled',
        () {
          binding.terminal.write(
            Uint8List.fromList(utf8.encode('\x1b[?1049h\x1b[?1007l')),
          );
          final output = <Uint8List>[];
          controller.onOutput = output.add;

          inputFor(binding).onScrollInput(
            const ScrollInput(
              horizontal: 0,
              mods: Mods.none(),
              pixelX: 24,
              pixelY: 16,
              reportMouse: false,
              vertical: -1,
            ),
          );

          expect(output, isEmpty);
        },
      );

      test('does not simulate cursor keys while mouse tracking is active', () {
        binding.terminal.write(Uint8List.fromList(utf8.encode('\x1b[?1049h')));
        enableMouseTracking(controller);
        final output = <Uint8List>[];
        controller.onOutput = output.add;

        inputFor(binding).onScrollInput(
          const ScrollInput(
            horizontal: 0,
            mods: Mods.none(),
            pixelX: 24,
            pixelY: 16,
            reportMouse: false,
            vertical: -1,
          ),
        );

        expect(output, isEmpty);
      });
    });

    group('sendText', () {
      test('emits UTF-8 bytes via onOutput', () {
        final output = <Uint8List>[];
        controller.onOutput = output.add;

        controller.sendText('hello');

        expect(output, hasLength(1));
        expect(utf8.decode(output.first), 'hello');
      });

      test('does not emit for empty text', () {
        final output = <Uint8List>[];
        controller.onOutput = output.add;

        controller.sendText('');

        expect(output, isEmpty);
      });
    });

    group('sendKey', () {
      test('encodes key output', () {
        final output = <Uint8List>[];
        controller.onOutput = output.add;

        controller.sendKey(Key.a);

        expect(output, hasLength(1));
        expect(utf8.decode(output.first), 'a');
      });

      test('ignores missing output callback', () {
        expect(() => controller.sendKey(Key.a), returnsNormally);
      });
    });

    group('onClipboardWrite', () {
      test('forwards binary clipboard requests', () {
        ClipboardWrite? received;
        controller.onClipboardWrite = (write) {
          received = write;
          return .success;
        };

        writeControllerUtf8(controller, '\x1b]52;c;aGVsbG8Ad29ybGQ=\x07');

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

      test('ignores clipboard requests without a handler', () {
        expect(
          () => writeControllerUtf8(controller, '\x1b]52;c;aGVsbG8=\x07'),
          returnsNormally,
        );
      });

      test('delivers clear requests without content', () {
        ClipboardWrite? received;
        controller.onClipboardWrite = (write) {
          received = write;
          return .success;
        };

        writeControllerUtf8(controller, '\x1b]52;s;\x07');

        expect(received?.contents, isEmpty);
      });

      test('forwards clipboard read queries and replies with content', () {
        ClipboardReadRequest? received;
        final output = <Uint8List>[];
        controller.onOutput = output.add;
        controller.onClipboardRead = (read) {
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

        writeControllerUtf8(controller, '\x1b]52;c;?\x07');

        expect(received?.mimes, ['text/plain']);
        expect(output, hasLength(1));
        expect(utf8.decode(output.single), '\x1b]52;c;aGVsbG8=\x07');
      });

      test('uses the replacement callback', () {
        var first = 0;
        var second = 0;
        controller.onClipboardWrite = (_) {
          first++;
          return .success;
        };
        controller.onClipboardWrite = (_) {
          second++;
          return .success;
        };

        writeControllerUtf8(controller, '\x1b]52;c;aGVsbG8=\x07');

        expect((first: first, second: second), (first: 0, second: 1));
      });

      test('stops delivery after callback removal', () {
        var count = 0;
        controller.onClipboardWrite = (_) {
          count++;
          return .success;
        };
        controller.onClipboardWrite = null;

        writeControllerUtf8(controller, '\x1b]52;c;aGVsbG8=\x07');

        expect(count, 0);
      });

      test('rethrows callback exceptions', () {
        final error = StateError('clipboard failed');
        controller.onClipboardWrite = (_) => throw error;

        expect(
          () => writeControllerUtf8(controller, '\x1b]52;c;aGVsbG8=\x07'),
          throwsA(same(error)),
        );
      });
    });

    group('onDesktopNotification', () {
      test('forwards OSC 9 notifications', () {
        DesktopNotification? notification;
        controller.onDesktopNotification = (value) => notification = value;

        writeControllerUtf8(controller, '\x1b]9;Build finished\x07');

        expect(
          notification,
          const DesktopNotification(title: '', body: 'Build finished'),
        );
      });
    });

    group('onProgressReport', () {
      test('forwards determinate OSC 9;4 reports', () {
        TerminalProgress? report;
        controller.onProgressReport = (value) => report = value;

        writeControllerUtf8(controller, '\x1b]9;4;1;42\x07');

        expect(report, const TerminalProgress(state: .set, progress: 42));
      });
    });

    group('selection', () {
      test('selectRange notifies listeners and installs selection', () {
        var notified = false;
        controller.addListener(() => notified = true);

        controller.selectRange(
          start: const Position(row: 0, col: 0),
          end: const Position(row: 0, col: 4),
        );

        expect(notified, isTrue);
        expect(controller.hasSelection, isTrue);
      });

      test('selection interaction observes per-screen selection changes', () {
        final viewToken = binding.attachView();
        addTearDown(() => binding.detachView(viewToken));
        final selectionInput = binding.createSelectionInteraction();
        addTearDown(selectionInput.dispose);
        controller.selectRange(
          start: const Position(row: 0, col: 0),
          end: const Position(row: 0, col: 4),
        );
        var notified = false;
        TerminalScreen? observedScreen;
        selectionInput.addListener(() {
          notified = true;
          observedScreen = binding.activeScreen;
        });

        writeTerminalUtf8(binding.terminal, '\x1b[?1049h');

        expect(notified, isTrue);
        expect(observedScreen, TerminalScreen.alternate);
        expect(selectionInput.selection, isNull);
      });

      test('selectRange skips notification when value is unchanged', () {
        controller.selectRange(
          start: const Position(row: 0, col: 0),
          end: const Position(row: 0, col: 4),
        );

        var notified = false;
        controller.addListener(() => notified = true);

        controller.selectRange(
          start: const Position(row: 0, col: 0),
          end: const Position(row: 0, col: 4),
        );

        expect(notified, isFalse);
      });

      test('clearSelection notifies only when selection was active', () {
        var notifyCount = 0;
        controller.addListener(() => notifyCount++);

        controller.clearSelection();
        expect(notifyCount, 0);

        controller.selectRange(
          start: const Position(row: 0, col: 0),
          end: const Position(row: 0, col: 4),
        );
        notifyCount = 0;

        controller.clearSelection();
        expect(notifyCount, 1);
        expect(controller.hasSelection, isFalse);
      });

      test('clearSelection ends an active selection gesture', () {
        controller.write(Uint8List.fromList(utf8.encode('hello')));
        final viewToken = binding.attachView();
        addTearDown(() => binding.detachView(viewToken));
        final selectionInput = binding.createSelectionInteraction();
        addTearDown(selectionInput.dispose);
        binding.handleResize(
          const SurfaceMeasurement(
            cols: 80,
            rows: 24,
            cellWidth: 8,
            cellHeight: 16,
            paddingLeft: 0,
            paddingRight: 0,
            paddingTop: 0,
            paddingBottom: 0,
            devicePixelRatio: 1,
          ),
        );
        selectionInput.handlePress(
          const SelectionPressInput(
            pixelX: 0,
            pixelY: 0,
            behaviors: SelectionGestureBehaviors.standard,
            wordBoundaries: null,
            repeatDistance: 18,
            repeatInterval: Duration(milliseconds: 300),
            timeStamp: Duration.zero,
            fullWidthLine: false,
          ),
        );
        selectionInput.handleDrag(
          const SelectionPointerInput(pixelX: 16, pixelY: 0, rectangle: false),
        );

        controller.clearSelection();
        selectionInput.handleDrag(
          const SelectionPointerInput(pixelX: 32, pixelY: 0, rectangle: false),
        );

        expect(controller.hasSelection, isFalse);
      });
    });

    group('scrollToBottom policy', () {
      TerminalController outputFollowController() {
        final target = TerminalController(
          config: const TerminalConfig(
            cols: 20,
            rows: 3,
            scrollToBottom: .onOutput,
          ),
        );
        addTearDown(target.dispose);
        return target;
      }

      void writeNumberedLines(TerminalController target) {
        for (var i = 0; i < 10; i++) {
          writeControllerUtf8(target, 'line $i\r\n');
        }
      }

      int scrollBack(TerminalController target) {
        writeNumberedLines(target);
        access(target).terminal.scrollViewport(-5);
        return access(target).terminal.scrollbar.offset;
      }

      test('scrolls to bottom on output when output follow is enabled', () {
        final custom = outputFollowController();
        final offset = scrollBack(custom);
        expect(offset, lessThan(custom.scrollbackRows));

        writeControllerUtf8(custom, 'tail\r\n');

        expect(access(custom).terminal.scrollbar.offset, custom.scrollbackRows);
      });

      test(
        'preserves viewport on selectRange when output follow is enabled',
        () {
          final custom = outputFollowController();
          final offset = scrollBack(custom);
          expect(offset, lessThan(custom.scrollbackRows));

          custom.selectRange(
            start: const Position(row: 0, col: 0),
            end: const Position(row: 0, col: 4),
          );

          expect(access(custom).terminal.scrollbar.offset, offset);
        },
      );

      test(
        'preserves viewport on clearSelection when output follow is enabled',
        () {
          final custom = outputFollowController();
          writeNumberedLines(custom);
          custom.selectRange(
            start: const Position(row: 0, col: 0),
            end: const Position(row: 0, col: 4),
          );
          access(custom).terminal.scrollViewport(-5);
          final offset = access(custom).terminal.scrollbar.offset;
          expect(offset, lessThan(custom.scrollbackRows));

          custom.clearSelection();

          expect(access(custom).terminal.scrollbar.offset, offset);
        },
      );

      test('preserves viewport when terminal geometry changes', () {
        final custom = outputFollowController();
        final offset = scrollBack(custom);
        expect(offset, lessThan(custom.scrollbackRows));

        access(custom).handleResize(
          const SurfaceMeasurement(
            cols: 20,
            rows: 3,
            cellWidth: 8,
            cellHeight: 16,
            paddingLeft: 0,
            paddingRight: 0,
            paddingTop: 0,
            paddingBottom: 0,
            devicePixelRatio: 1,
          ),
        );

        expect(access(custom).terminal.scrollbar.offset, offset);
      });

      test('preserves viewport when a terminal mode changes', () {
        final custom = outputFollowController();
        final offset = scrollBack(custom);
        expect(offset, lessThan(custom.scrollbackRows));

        custom.modeSet(const .bracketedPaste(), value: true);

        expect(access(custom).terminal.scrollbar.offset, offset);
      });
    });

    group('selectAll', () {
      test('selects visible content', () {
        writeControllerUtf8(controller, 'hello\r\nworld');

        controller.selectAll();

        expect(controller.hasSelection, isTrue);
        expect(controller.selectedText(), 'hello\nworld');
      });

      test('leaves selection empty on an empty screen', () {
        controller.selectAll();

        expect(controller.hasSelection, isFalse);
      });

      test('selects a single content row', () {
        writeControllerUtf8(controller, 'abc');

        controller.selectAll();

        expect(controller.hasSelection, isTrue);
        expect(controller.selectedText(), 'abc');
      });
    });

    group('selectedText', () {
      test('returns selected screen text', () {
        replaceController(const TerminalConfig(cols: 20, rows: 5));
        writeControllerUtf8(controller, 'hello world');

        controller.selectRange(
          start: const Position(row: 0, col: 0),
          end: const Position(row: 0, col: 4),
        );

        expect(controller.selectedText(), 'hello');
      });

      test('uses the requested formatter', () {
        replaceController(const TerminalConfig(cols: 20, rows: 5));
        writeControllerUtf8(controller, '\x1b[31mhi\x1b[0m');

        controller.selectRange(
          start: const Position(row: 0, col: 0),
          end: const Position(row: 0, col: 1),
        );

        expect(controller.selectedText(), 'hi');
        expect(
          controller.selectedText(format: FormatterFormat.vt),
          contains('hi'),
        );
        expect(
          controller.selectedText(format: FormatterFormat.html),
          contains('<'),
        );
      });

      test('excludes wide-character spacer tails', () {
        replaceController(const TerminalConfig(cols: 20, rows: 5));
        controller.write(Uint8List.fromList(utf8.encode('日本語')));

        controller.selectRange(
          start: const Position(row: 0, col: 0),
          end: const Position(row: 0, col: 4),
        );
        expect(controller.selectedText(), '日本語');

        controller.selectRange(
          start: const Position(row: 0, col: 0),
          end: const Position(row: 0, col: 4),
          rectangle: true,
        );
        expect(controller.selectedText(), '日本語');
      });
    });

    group('scrollback selection', () {
      late TerminalController smallController;

      setUp(() {
        smallController = TerminalController(
          config: const TerminalConfig(cols: 20, rows: 3),
        );
      });

      tearDown(() => smallController.dispose());

      void writeLines(List<String> lines) {
        writeControllerUtf8(smallController, lines.join('\r\n'));
      }

      test('selectAll includes scrollback rows', () {
        writeLines(['aaa', 'bbb', 'ccc', 'ddd', 'eee']);
        final scrollbackLen = smallController.scrollbackRows;
        expect(scrollbackLen, 2);

        smallController.selectAll();

        expect(smallController.hasSelection, isTrue);
        expect(smallController.selectedText(), 'aaa\nbbb\nccc\nddd\neee');
      });

      test('selectAll with only scrollback content', () {
        writeLines(['aaa', 'bbb', 'ccc', '']);
        final scrollbackLen = smallController.scrollbackRows;
        expect(scrollbackLen, greaterThan(0));

        smallController.selectAll();

        expect(smallController.hasSelection, isTrue);
        expect(smallController.selectedText(), contains('aaa'));
      });

      test('selectRange throws for selection beyond screen bounds', () {
        writeLines(['aaa', 'bbb', 'ccc']);
        expect(
          () => smallController.selectRange(
            start: const Position(row: 0, col: 0),
            end: const Position(row: 99, col: 19),
          ),
          throwsA(isA<LibGhosttyException>()),
        );
      });

      test('selectedText extracts from scrollback and screen', () {
        writeLines(['aaa', 'bbb', 'ccc', 'ddd', 'eee']);
        final scrollbackLen = smallController.scrollbackRows;
        expect(scrollbackLen, 2);

        smallController.selectAll();

        final text = smallController.selectedText();
        expect(text, contains('aaa'));
        expect(text, contains('bbb'));
        expect(text, contains('ccc'));
        expect(text, contains('ddd'));
        expect(text, contains('eee'));
      });

      test('selectedText joins wrapped lines without newline', () {
        final wrapController = TerminalController(
          config: const TerminalConfig(cols: 5, rows: 3),
        );
        addTearDown(wrapController.dispose);
        writeControllerUtf8(wrapController, 'abcdefgh');

        wrapController.selectAll();

        final text = wrapController.selectedText();
        expect(text, 'abcdefgh');
        expect(text, isNot(contains('\n')));
      });

      test('selectedText with wrapped wide characters', () {
        final wrapController = TerminalController(
          config: const TerminalConfig(cols: 5, rows: 3),
        );
        addTearDown(wrapController.dispose);
        wrapController.write(Uint8List.fromList(utf8.encode('A日B日C')));
        wrapController.selectAll();

        expect(wrapController.selectedText(), 'A日B日C');
      });

      test('selectedText in block mode inserts newlines between rows', () {
        writeLines(['aaaa', 'bbbb', 'cccc']);
        smallController.selectRange(
          start: const Position(row: 0, col: 1),
          end: const Position(row: 2, col: 2),
          rectangle: true,
        );

        final text = smallController.selectedText();
        final lines = text.split('\n');
        expect(lines.length, 3);
        expect(lines[0], 'aa');
        expect(lines[1], 'bb');
        expect(lines[2], 'cc');
      });

      test('selectedText with partial scrollback selection', () {
        writeLines(['aaa', 'bbb', 'ccc', 'ddd']);
        expect(smallController.scrollbackRows, 1);

        smallController.selectRange(
          start: const Position(row: 0, col: 0),
          end: const Position(row: 1, col: 2),
        );

        final text = smallController.selectedText();
        expect(text, contains('aaa'));
        expect(text, contains('bbb'));
        expect(text, isNot(contains('ccc')));
      });
    });

    group('clear', () {
      test('emits form feed', () {
        final output = <Uint8List>[];
        controller.onOutput = output.add;

        controller.clear();

        expect(output, hasLength(1));
        final decoded = utf8.decode(output.first);
        expect(decoded, '\x0c');
      });

      test('writes erase scrollback to terminal', () {
        writeControllerUtf8(controller, 'hello\r\nworld\r\n');

        controller.clear();

        expect(controller.scrollbackRows, 0);
      });

      test('does nothing on alternate screen', () {
        final output = <Uint8List>[];
        controller.onOutput = output.add;
        writeControllerUtf8(controller, '\x1b[?1049h');

        controller.clear();

        expect(output, isEmpty);
      });

      test('clears selection', () {
        controller.selectRange(
          start: const Position(row: 0, col: 0),
          end: const Position(row: 1, col: 4),
        );

        controller.clear();

        expect(controller.hasSelection, isFalse);
      });
    });

    group('paste', () {
      test('sends text via onOutput', () {
        final output = <Uint8List>[];
        controller.onOutput = output.add;

        controller.paste('hello');

        expect(output, hasLength(1));
        expect(utf8.decode(output.first), 'hello');
      });

      test('wraps with bracketed paste escape when mode is active', () {
        binding.terminal.modeSet(
          const TerminalMode.bracketedPaste(),
          value: true,
        );
        final output = <Uint8List>[];
        controller.onOutput = output.add;

        controller.paste('hello');

        expect(output, hasLength(1));
        final decoded = utf8.decode(output.first);
        expect(decoded, contains('\x1b[200~'));
        expect(decoded, contains('hello'));
        expect(decoded, contains('\x1b[201~'));
      });

      test('empty text does not emit', () {
        final output = <Uint8List>[];
        controller.onOutput = output.add;

        controller.paste('');

        expect(output, isEmpty);
      });
    });

    group('config', () {
      Uint8List transmitRedPixel({int id = 42}) {
        return .fromList('\x1b_Gf=24,s=1,v=1,a=t,i=$id;/wAA\x1b\\'.codeUnits);
      }

      test('getter returns initial config', () {
        final custom = TerminalController(
          config: const TerminalConfig(cols: 120, rows: 40),
        );
        addTearDown(custom.dispose);

        expect(custom.config.cols, 120);
        expect(custom.config.rows, 40);
      });

      test('setter updates config', () {
        controller.config = const TerminalConfig(cols: 120, rows: 40);
        expect(controller.config.cols, 120);
      });

      test('initial config applies terminal options', () {
        final custom = TerminalController(
          config: const TerminalConfig(
            scrollbackMaxBytes: 1024,
            scrollbackMaxLines: 10,
            kittyImageStorageLimit: 1 << 20,
            apcBufferLimit: 1,
            clipboardWriteMaxBytes: 1024,
            cursorStyle: CursorShape.underline,
            cursorBlink: true,
          ),
        );
        final renderState = RenderState();
        addTearDown(custom.dispose);
        addTearDown(renderState.dispose);

        expect(access(custom).terminal.scrollbackMaxBytes, 1024);
        expect(access(custom).terminal.scrollbackMaxLines, 10);
        expect(access(custom).terminal.clipboardWriteMaxBytes, 1024);

        custom.write(transmitRedPixel(id: 91));

        expect(KittyGraphics.of(access(custom).terminal)!.image(91), isNull);

        writeTerminalUtf8(access(custom).terminal, '\x1b[0 q');
        renderState.update(access(custom).terminal);

        expect(renderState.cursor.visualStyle, CursorShape.underline);
        expect(renderState.cursor.blinking, isTrue);
      });

      test('setter applies scrollback limits', () {
        controller.config = const TerminalConfig(
          scrollbackMaxBytes: 2048,
          scrollbackMaxLines: 20,
        );

        expect(binding.terminal.scrollbackMaxBytes, 2048);
        expect(binding.terminal.scrollbackMaxLines, 20);
      });

      test('setter applies APC buffer limits', () {
        controller.config = const TerminalConfig(apcBufferLimit: 1);

        controller.write(transmitRedPixel(id: 92));

        expect(KittyGraphics.of(binding.terminal)!.image(92), isNull);
      });

      test('setter applies cursor reset defaults', () {
        final renderState = RenderState();
        addTearDown(renderState.dispose);

        controller.config = const TerminalConfig(
          cursorStyle: CursorShape.bar,
          cursorBlink: false,
        );
        writeTerminalUtf8(binding.terminal, '\x1b[0 q');
        renderState.update(binding.terminal);

        expect(renderState.cursor.visualStyle, CursorShape.bar);
        expect(renderState.cursor.blinking, isFalse);
      });
    });

    group('modeGet and modeSet', () {
      test('modeSet enables and modeGet reads back', () {
        controller.modeSet(const TerminalMode.autoWrap(), value: false);
        expect(controller.modeGet(const TerminalMode.autoWrap()), isFalse);

        controller.modeSet(const TerminalMode.autoWrap(), value: true);
        expect(controller.modeGet(const TerminalMode.autoWrap()), isTrue);
      });

      test('modeSet notifies listeners for observed mode changes', () {
        var notifyCount = 0;
        controller.addListener(() => notifyCount++);

        controller.modeSet(const TerminalMode.alternateScroll(), value: false);

        expect(notifyCount, 1);
      });
    });

    group('activeScreen', () {
      test('defaults to primary', () {
        expect(controller.activeScreen, TerminalScreen.primary);
      });

      test('switches to alternate via escape sequence', () {
        writeTerminalUtf8(binding.terminal, '\x1b[?1049h');
        expect(controller.activeScreen, TerminalScreen.alternate);
      });
    });

    group('title', () {
      test('defaults to empty', () {
        expect(controller.title, isEmpty);
      });

      test('updates via OSC 0 escape sequence', () {
        writeTerminalUtf8(binding.terminal, '\x1b]0;my title\x1b\\');
        expect(controller.title, 'my title');
      });

      test('fires onTitleChanged callback', () {
        var fired = false;
        controller.onTitleChanged = () => fired = true;

        writeTerminalUtf8(binding.terminal, '\x1b]0;new title\x1b\\');

        expect(fired, isTrue);
      });
    });

    group('pwd', () {
      test('updates via OSC 7 escape sequence', () {
        writeTerminalUtf8(binding.terminal, '\x1b]7;file:///tmp\x07');

        expect(controller.pwd, 'file:///tmp');
      });

      test('notifies listeners on OSC 7 change', () {
        var notifyCount = 0;
        controller.addListener(() => notifyCount++);

        writeTerminalUtf8(binding.terminal, '\x1b]7;file:///tmp\x07');

        expect(notifyCount, greaterThan(0));
      });

      test('notifies listeners once when a PWD callback is set', () {
        var notifyCount = 0;
        controller.onPwdChanged = () {};
        controller.addListener(() => notifyCount++);

        writeTerminalUtf8(binding.terminal, '\x1b]7;file:///tmp\x07');

        expect(notifyCount, 1);
      });

      test('keeps observing PWD changes after callback is cleared', () {
        var notifyCount = 0;
        controller.onPwdChanged = () {};
        controller.onPwdChanged = null;
        controller.addListener(() => notifyCount++);

        writeTerminalUtf8(binding.terminal, '\x1b]7;file:///tmp\x07');

        expect(notifyCount, 1);
      });

      test('fires onPwdChanged callback', () {
        var fired = false;
        controller.onPwdChanged = () => fired = true;

        writeTerminalUtf8(binding.terminal, '\x1b]7;file:///tmp\x07');

        expect(fired, isTrue);
      });

      test('exposes updated value during onPwdChanged callback', () {
        var pwd = '';
        controller.onPwdChanged = () => pwd = controller.pwd;

        writeTerminalUtf8(binding.terminal, '\x1b]7;file:///tmp\x07');

        expect(pwd, 'file:///tmp');
      });
    });

    group('dispose', () {
      test('releases resources', () {
        final disposable = TerminalController();

        expect(disposable.dispose, returnsNormally);
      });

      test('allows repeated disposal', () {
        controller.dispose();

        expect(controller.dispose, returnsNormally);
      });

      test('rejects writes after disposal', () {
        controller.dispose();

        expect(
          () => controller.write(Uint8List.fromList([0x61])),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('virtual mods', () {
      test('toggleMod activates, deactivates, and combines modifiers', () {
        expect(controller.virtualMods, const Mods.none());

        controller.toggleMod(const Mods.ctrl());
        expect(controller.virtualMods.hasCtrl, isTrue);

        controller.toggleMod(const Mods.alt());
        expect(controller.virtualMods.hasCtrl, isTrue);
        expect(controller.virtualMods.hasAlt, isTrue);

        controller.toggleMod(const Mods.ctrl());
        expect(controller.virtualMods.hasCtrl, isFalse);
        expect(controller.virtualMods.hasAlt, isTrue);

        controller.toggleMod(const Mods.alt());
        expect(controller.virtualMods, const Mods.none());
      });

      test('toggleMod notifies listeners', () {
        var notified = false;
        controller.addListener(() => notified = true);

        controller.toggleMod(const Mods.ctrl());

        expect(notified, isTrue);
      });

      test('clearVirtualMods notifies only when mods were active', () {
        var notifyCount = 0;
        controller.addListener(() => notifyCount++);

        controller.clearVirtualMods();
        expect(notifyCount, 0);

        controller.toggleMod(const Mods.ctrl());
        notifyCount = 0;

        controller.clearVirtualMods();
        expect(notifyCount, 1);
        expect(controller.virtualMods, const Mods.none());
      });

      test('sendKey merges virtual mods', () {
        final output = <Uint8List>[];
        controller.onOutput = output.add;

        controller.toggleMod(const Mods.ctrl());
        controller.sendKey(Key.c);

        expect(output, hasLength(1));
        expect(output.first, equals(utf8.encode('\x03')));
      });

      test('sendKey clears virtual mods after encoding', () {
        controller.onOutput = (_) {};

        controller.toggleMod(const Mods.ctrl());
        controller.sendKey(Key.a);

        expect(controller.virtualMods, const Mods.none());
      });

      test('sendKey merges explicit and virtual mods', () {
        final output = <Uint8List>[];
        controller.onOutput = output.add;

        controller.toggleMod(const Mods.ctrl());
        controller.sendKey(Key.c, mods: const Mods.shift());

        expect(output, hasLength(1));
        expect(controller.virtualMods, const Mods.none());
      });

      test('sendText clears virtual mods', () {
        controller.onOutput = (_) {};

        controller.toggleMod(const Mods.ctrl());
        controller.sendText('hello');

        expect(controller.virtualMods, const Mods.none());
      });

      test('sendText does not clear when text is empty', () {
        controller.toggleMod(const Mods.ctrl());
        controller.sendText('');

        expect(controller.virtualMods.hasCtrl, isTrue);
      });
    });
  });
}

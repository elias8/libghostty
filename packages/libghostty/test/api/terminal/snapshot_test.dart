import 'dart:typed_data';

import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

import '../../helpers/setup.dart';

void main() {
  setUp(() => testEnvironment);

  group('Terminal', () {
    group('encodeSnapshot', () {
      test('rejects unfinished input without continuation tracking', () {
        final terminal = Terminal(cols: 8, rows: 2);
        addTearDown(terminal.dispose);
        terminal.write(Uint8List.fromList('\x1b['.codeUnits));

        final encode = terminal.encodeSnapshot;

        expect(encode, throwsA(isA<InvalidValueException>()));
      });
    });
  });

  group('SnapshotDecoder', () {
    String plainText(Terminal terminal) {
      final formatter = Formatter(
        terminal: terminal,
        format: FormatterFormat.plain,
      );
      addTearDown(formatter.dispose);
      return formatter.format();
    }

    Terminal terminalWithHistory() {
      final terminal = Terminal(cols: 6, rows: 2);
      terminal.scrollbackMaxLines = 20000;
      final content = List.generate(
        10000,
        (index) => 'line$index',
      ).join('\r\n');
      terminal.write(Uint8List.fromList(content.codeUnits));
      return terminal;
    }

    List<SnapshotProgress> drainPages(SnapshotDecoder decoder) {
      final pages = <SnapshotProgress>[];
      SnapshotProgress? page;
      while ((page = decoder.next()) != null) {
        pages.add(page!);
      }
      return pages;
    }

    group('constructor', () {
      test('does not compress history by default', () {
        final source = Terminal(cols: 4, rows: 1);
        addTearDown(source.dispose);
        final decoder = SnapshotDecoder(source.encodeSnapshot());
        addTearDown(decoder.dispose);

        expect(decoder.compressHistory, isFalse);
      });

      test('copies source bytes at construction', () {
        final source = Terminal(cols: 8, rows: 2);
        addTearDown(source.dispose);
        source.write(Uint8List.fromList('copy'.codeUnits));
        final bytes = source.encodeSnapshot();
        final decoder = SnapshotDecoder(bytes);
        addTearDown(decoder.dispose);
        bytes.fillRange(0, bytes.length, 0);

        final restored = decoder.decode();
        addTearDown(restored.dispose);

        expect(plainText(restored), startsWith('copy'));
      });

      test('rejects a continuation limit below zero', () {
        SnapshotDecoder create() =>
            SnapshotDecoder(Uint8List(0), maxContinuationBytes: -1);

        expect(create, throwsRangeError);
      });

      test('rejects a continuation limit above the uint32 maximum', () {
        SnapshotDecoder create() =>
            SnapshotDecoder(Uint8List(0), maxContinuationBytes: 0x100000000);

        expect(create, throwsRangeError);
      });
    });

    group('decode', () {
      test('restores terminal geometry', () {
        final source = Terminal(cols: 12, rows: 3);
        addTearDown(source.dispose);
        final decoder = SnapshotDecoder(source.encodeSnapshot());
        addTearDown(decoder.dispose);

        final restored = decoder.decode();
        addTearDown(restored.dispose);

        expect(restored.geometry, source.geometry);
      });

      test('restores terminal content', () {
        final source = Terminal(cols: 12, rows: 3);
        addTearDown(source.dispose);
        source.write(Uint8List.fromList('hello'.codeUnits));
        final decoder = SnapshotDecoder(source.encodeSnapshot());
        addTearDown(decoder.dispose);

        final restored = decoder.decode();
        addTearDown(restored.dispose);

        expect(plainText(restored), startsWith('hello'));
      });

      test('rejects reuse after successful decoding', () {
        final source = Terminal(cols: 4, rows: 1);
        addTearDown(source.dispose);
        final decoder = SnapshotDecoder(source.encodeSnapshot());
        addTearDown(decoder.dispose);
        final restored = decoder.decode();
        addTearDown(restored.dispose);

        final decode = decoder.decode;

        expect(decode, throwsStateError);
      });

      test('retains unfinished input when requested', () {
        final source = Terminal(cols: 8, rows: 2)..continuationMaxBytes = 1024;
        addTearDown(source.dispose);
        source.write(Uint8List.fromList('\x1b['.codeUnits));
        final decoder = SnapshotDecoder(
          source.encodeSnapshot(),
          maxContinuationBytes: 1024,
          retainContinuation: true,
        );
        addTearDown(decoder.dispose);

        final restored = decoder.decode();
        addTearDown(restored.dispose);

        expect(restored.continuation, Uint8List.fromList('\x1b['.codeUnits));
      });

      test('rejects unfinished input over the configured limit', () {
        final source = Terminal(cols: 8, rows: 2)..continuationMaxBytes = 1024;
        addTearDown(source.dispose);
        source.write(Uint8List.fromList('\x1b['.codeUnits));
        final decoder = SnapshotDecoder(
          source.encodeSnapshot(),
          maxContinuationBytes: 0,
        );
        addTearDown(decoder.dispose);

        final decode = decoder.decode;

        expect(decode, throwsA(isA<LimitExceededException>()));
      });

      test('rejects malformed snapshot data', () {
        final decoder = SnapshotDecoder(Uint8List.fromList([1, 2, 3]));
        addTearDown(decoder.dispose);

        final decode = decoder.decode;

        expect(decode, throwsA(isA<InvalidValueException>()));
      });

      test('leaves the restored terminal usable after decoder disposal', () {
        final source = Terminal(cols: 8, rows: 2);
        addTearDown(source.dispose);
        source.write(Uint8List.fromList('alive'.codeUnits));
        final decoder = SnapshotDecoder(source.encodeSnapshot());
        final restored = decoder.decode();
        addTearDown(restored.dispose);

        decoder.dispose();

        expect(plainText(restored), startsWith('alive'));
      });
    });

    group('ready', () {
      test('returns a renderable terminal before history pages', () {
        final source = terminalWithHistory();
        addTearDown(source.dispose);
        final decoder = SnapshotDecoder(source.encodeSnapshot());
        addTearDown(decoder.dispose);

        final restored = decoder.ready();
        addTearDown(restored.dispose);

        expect(restored.geometry, source.geometry);
      });

      test('rejects restoration after the returned terminal is disposed', () {
        final source = terminalWithHistory();
        addTearDown(source.dispose);
        final decoder = SnapshotDecoder(source.encodeSnapshot());
        addTearDown(decoder.dispose);
        decoder.ready().dispose();

        final next = decoder.next;

        expect(next, throwsStateError);
      });
    });

    group('next', () {
      test('rejects calls before ready', () {
        final source = Terminal(cols: 4, rows: 1);
        addTearDown(source.dispose);
        final decoder = SnapshotDecoder(source.encodeSnapshot());
        addTearDown(decoder.dispose);

        final next = decoder.next;

        expect(next, throwsStateError);
      });

      test('restores history pages incrementally', () {
        final source = terminalWithHistory();
        addTearDown(source.dispose);
        final decoder = SnapshotDecoder(source.encodeSnapshot());
        addTearDown(decoder.dispose);
        final restored = decoder.ready();
        addTearDown(restored.dispose);

        final pages = drainPages(decoder);

        expect(pages, isNotEmpty);
        expect(restored.scrollbackRows, source.scrollbackRows);
      });

      test('compresses history while restoring pages when requested', () {
        final source = terminalWithHistory();
        addTearDown(source.dispose);
        final decoder = SnapshotDecoder(
          source.encodeSnapshot(),
          compressHistory: true,
        );
        addTearDown(decoder.dispose);

        final restored = decoder.ready();
        addTearDown(restored.dispose);
        final pages = drainPages(decoder);

        expect(pages, isNotEmpty);
        expect(decoder.compressHistory, isTrue);
        expect(restored.scrollbackRows, source.scrollbackRows);
        expect(plainText(restored), plainText(source));
      });

      test('returns null after the final history page', () {
        final source = terminalWithHistory();
        addTearDown(source.dispose);
        final decoder = SnapshotDecoder(source.encodeSnapshot());
        addTearDown(decoder.dispose);
        final restored = decoder.ready();
        addTearDown(restored.dispose);
        drainPages(decoder);

        final progress = decoder.next();

        expect(progress, isNull);
      });

      test('reports malformed history as an invalid-value failure', () {
        final source = terminalWithHistory();
        addTearDown(source.dispose);
        final snapshot = source.encodeSnapshot();
        snapshot[snapshot.length - 1] ^= 0xff;
        final decoder = SnapshotDecoder(snapshot);
        addTearDown(decoder.dispose);
        final restored = decoder.ready();
        addTearDown(restored.dispose);

        List<SnapshotProgress> restore() => drainPages(decoder);

        expect(restore, throwsA(isA<InvalidValueException>()));
      });

      test('preserves primary history metadata after history failure', () {
        final source = terminalWithHistory();
        addTearDown(source.dispose);
        final snapshot = source.encodeSnapshot();
        snapshot[snapshot.length - 1] ^= 0xff;
        final decoder = SnapshotDecoder(snapshot);
        addTearDown(decoder.dispose);
        final restored = decoder.ready();
        addTearDown(restored.dispose);
        final historyRows = decoder.primaryHistoryRows;
        expect(
          () => drainPages(decoder),
          throwsA(isA<InvalidValueException>()),
        );

        final metadata = decoder.primaryHistoryRows;

        expect(metadata, historyRows);
      });
    });

    group('metadata', () {
      test('reports primary history rows after ready', () {
        final source = terminalWithHistory();
        addTearDown(source.dispose);
        final decoder = SnapshotDecoder(source.encodeSnapshot());
        addTearDown(decoder.dispose);
        final restored = decoder.ready();
        addTearDown(restored.dispose);

        final rows = decoder.primaryHistoryRows;

        expect(rows, source.scrollbackRows);
      });

      test('reports no alternate history rows when absent', () {
        final source = Terminal(cols: 4, rows: 1);
        addTearDown(source.dispose);
        final decoder = SnapshotDecoder(source.encodeSnapshot());
        addTearDown(decoder.dispose);
        final restored = decoder.ready();
        addTearDown(restored.dispose);

        final rows = decoder.alternateHistoryRows;

        expect(rows, isNull);
      });

      test('reports whether continuation retention was requested', () {
        final source = Terminal(cols: 4, rows: 1);
        addTearDown(source.dispose);
        final decoder = SnapshotDecoder(
          source.encodeSnapshot(),
          retainContinuation: true,
        );
        addTearDown(decoder.dispose);
        final restored = decoder.decode();
        addTearDown(restored.dispose);

        final retained = decoder.retainContinuation;

        expect(retained, isTrue);
      });
    });

    group('sourceOffset', () {
      test('reports the first byte after the snapshot', () {
        final source = Terminal(cols: 8, rows: 2);
        addTearDown(source.dispose);
        final snapshot = source.encodeSnapshot();
        final decoder = SnapshotDecoder(
          Uint8List.fromList([...snapshot, 1, 2, 3]),
        );
        addTearDown(decoder.dispose);
        final restored = decoder.decode();
        addTearDown(restored.dispose);

        final offset = decoder.sourceOffset;

        expect(offset, snapshot.length);
      });

      test('rejects access after decoding fails', () {
        final decoder = SnapshotDecoder(Uint8List.fromList([1, 2, 3]));
        addTearDown(decoder.dispose);
        expect(decoder.decode, throwsA(isA<InvalidValueException>()));

        int read() => decoder.sourceOffset;

        expect(read, throwsStateError);
      });

      test('rejects access after disposal', () {
        final source = Terminal(cols: 4, rows: 1);
        addTearDown(source.dispose);
        final decoder = SnapshotDecoder(source.encodeSnapshot());
        decoder.dispose();

        int read() => decoder.sourceOffset;

        expect(read, throwsStateError);
      });
    });

    group('dispose', () {
      test('is idempotent', () {
        final source = Terminal(cols: 4, rows: 1);
        addTearDown(source.dispose);
        final decoder = SnapshotDecoder(source.encodeSnapshot());
        decoder.dispose();

        final dispose = decoder.dispose;

        expect(dispose, returnsNormally);
      });

      test('rejects decode after disposal', () {
        final source = Terminal(cols: 4, rows: 1);
        addTearDown(source.dispose);
        final decoder = SnapshotDecoder(source.encodeSnapshot());
        decoder.dispose();

        final decode = decoder.decode;

        expect(decode, throwsStateError);
      });
    });
  });
}

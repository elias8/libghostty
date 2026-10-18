@Tags(['ffi'])
library;

import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'package:libghostty/src/bindings/terminal/ffi.dart';
import 'package:libghostty/src/bindings/types.dart';
import 'package:libghostty/src/generated/libghostty_enums.g.dart';
import 'package:libghostty/src/types/exceptions.dart';
import 'package:libghostty/src/types/geometry.dart';
import 'package:libghostty/src/types/terminal.dart';
import 'package:test/test.dart';

void main() {
  group('FfiTerminalBindings', () {
    late FfiTerminalBindings bindings;

    setUp(() {
      bindings = FfiTerminalBindings();
    });

    LibGhosttyHandle createTerminal() {
      final terminal = bindings.terminalNew(8, 4);
      addTearDown(() => bindings.terminalFree(terminal));
      return terminal;
    }

    test(
      'creates, queries, and resizes a terminal through the direct adapter',
      () {
        final terminal = createTerminal();

        expect(
          bindings.terminalGetGeometry(terminal),
          const TerminalGeometry(cols: 8, rows: 4, widthPx: 0, heightPx: 0),
        );

        bindings.terminalResize(terminal, 10, 6, 8, 16);
        expect(bindings.terminalGetCols(terminal), 10);
        expect(bindings.terminalGetRows(terminal), 6);
        expect(bindings.terminalGetWidthPx(terminal), 80);
        expect(bindings.terminalGetHeightPx(terminal), 96);
      },
    );

    test(
      'maps optional terminal configuration values to nullable Dart values',
      () {
        final terminal = createTerminal();

        expect(bindings.terminalGetScrollbackMaxBytes(terminal), isA<int>());
        expect(bindings.terminalGetScrollbackMaxLines(terminal), isNull);
        expect(
          bindings.terminalGetKittyImageStorageLimit(terminal),
          isA<int>(),
        );
        expect(bindings.terminalGetKittyImageMediumFile(terminal), isA<bool>());
        expect(
          bindings.terminalGetKittyImageMediumSharedMem(terminal),
          isA<bool>(),
        );
        expect(
          bindings.terminalGetKittyImageMediumTempFile(terminal),
          isA<String>(),
        );
      },
    );

    for (final version in [false, true]) {
      for (final action in ['clear', 'replace', 'throw']) {
        test('${version ? 'XTVERSION' : 'ENQ'} retires reply on $action', () {
          final allocator = _FailingCallbackAllocator();
          addTearDown(allocator.dispose);
          final adapter = FfiTerminalBindings(callbackAllocator: allocator);
          final terminal = adapter.terminalNew(8, 4);
          addTearDown(() => adapter.terminalFree(terminal));
          final replies = <String>[];
          adapter.terminalSetOnWritePty(terminal, (bytes) {
            expect(allocator.freeCounts, isEmpty);
            replies.add(String.fromCharCodes(bytes));
          });
          final failure = StateError('reply failure');
          var calls = 0;
          String reply() {
            calls++;
            if (version) {
              adapter.terminalSetOnXtversion(terminal, null);
              if (action == 'replace') {
                adapter.terminalSetOnXtversion(terminal, () => 'second');
              }
            } else {
              adapter.terminalSetOnEnquiry(terminal, null);
              if (action == 'replace') {
                adapter.terminalSetOnEnquiry(
                  terminal,
                  () => Uint8List.fromList('second'.codeUnits),
                );
              }
            }
            expect(allocator.freeCounts, isEmpty);
            if (action == 'throw') throw failure;
            return 'first';
          }

          if (version) {
            adapter.terminalSetOnXtversion(terminal, reply);
          } else {
            adapter.terminalSetOnEnquiry(
              terminal,
              () => Uint8List.fromList(reply().codeUnits),
            );
          }
          final query = version ? '\x1b[>q' : '\x05';
          void write() => adapter.terminalVtWrite(
            terminal,
            Uint8List.fromList('$query$query'.codeUnits),
          );
          if (action == 'throw') {
            expect(write, throwsA(same(failure)));
          } else {
            write();
            expect(replies.first, contains('first'));
            if (action == 'replace') {
              expect(replies.last, contains('second'));
            }
          }
          expect(calls, 1);
          expect(allocator.freeCounts, isNotEmpty);
          expect(allocator.freeCounts.values, everyElement(1));
        });
      }
    }

    test('keeps retired version storage through write-until-ground', () {
      final allocator = _FailingCallbackAllocator();
      addTearDown(allocator.dispose);
      final adapter = FfiTerminalBindings(callbackAllocator: allocator);
      final terminal = adapter.terminalNew(8, 4);
      addTearDown(() => adapter.terminalFree(terminal));
      final replies = <String>[];
      adapter.terminalSetOnWritePty(terminal, (bytes) {
        expect(allocator.freeCounts, isEmpty);
        replies.add(String.fromCharCodes(bytes));
      });
      adapter.terminalSetOnXtversion(terminal, () {
        adapter.terminalSetOnXtversion(terminal, null);
        adapter.terminalVtWrite(
          terminal,
          Uint8List.fromList('nested'.codeUnits),
        );
        expect(allocator.freeCounts, isEmpty);
        return 'first';
      });
      adapter.terminalVtWrite(terminal, Uint8List.fromList('\x1b[>'.codeUnits));
      expect(
        adapter.terminalWriteUntilGround(
          terminal,
          Uint8List.fromList('q'.codeUnits),
        ),
        1,
      );
      expect(replies.single, contains('first'));
      expect(allocator.freeCounts.values, everyElement(1));
      expect(
        allocator.freeCounts.keys.toSet(),
        allocator.allocations.keys.toSet(),
      );
    });

    test('keeps enquiry storage valid after allocation failure', () {
      final allocator = _FailingCallbackAllocator();
      addTearDown(allocator.dispose);
      final callbackBindings = FfiTerminalBindings(
        callbackAllocator: allocator,
      );
      final terminal = callbackBindings.terminalNew(8, 4);
      addTearDown(() => callbackBindings.terminalFree(terminal));
      final replies = <List<int>>[];
      callbackBindings.terminalSetOnWritePty(
        terminal,
        (bytes) => replies.add(bytes.toList()),
      );
      var reply = Uint8List.fromList([65, 66]);
      callbackBindings.terminalSetOnEnquiry(terminal, () => reply);
      final enquiry = Uint8List.fromList([5]);
      callbackBindings.terminalVtWrite(terminal, enquiry);
      expect(replies, [
        [65, 66],
      ]);

      reply = Uint8List.fromList([65, 66, 67, 68]);
      allocator.failNext = true;
      expect(
        () => callbackBindings.terminalVtWrite(terminal, enquiry),
        throwsA(same(allocator.failure)),
      );
      expect(allocator.freeCounts, isEmpty);
      callbackBindings.terminalVtWrite(terminal, enquiry);
      expect(replies, [
        [65, 66],
        [65, 66, 67, 68],
      ]);
      callbackBindings.terminalSetOnEnquiry(terminal, null);
      expect(allocator.freeCounts.values, everyElement(1));
      expect(
        allocator.freeCounts.keys.toSet(),
        allocator.allocations.keys.toSet(),
      );
    });

    test(
      'reuses exact reply sizes and releases storage on shrink and clear',
      () {
        final allocator = _FailingCallbackAllocator();
        addTearDown(allocator.dispose);
        final callbackBindings = FfiTerminalBindings(
          callbackAllocator: allocator,
        );
        final terminal = callbackBindings.terminalNew(8, 4);
        addTearDown(() => callbackBindings.terminalFree(terminal));
        final replies = <List<int>>[];
        callbackBindings.terminalSetOnWritePty(
          terminal,
          (bytes) => replies.add(bytes.toList()),
        );
        var reply = Uint8List.fromList([65, 66, 67, 68]);
        callbackBindings.terminalSetOnEnquiry(terminal, () => reply);
        final enquiry = Uint8List.fromList([5]);
        callbackBindings.terminalVtWrite(terminal, enquiry);
        final warmed = allocator.allocations.length;
        reply = Uint8List.fromList([69, 70, 71, 72]);
        callbackBindings.terminalVtWrite(terminal, enquiry);
        expect(allocator.allocations, hasLength(warmed));
        expect(allocator.freeCounts, isEmpty);
        callbackBindings.terminalSetOnEnquiry(
          terminal,
          () => Uint8List.fromList([73, 74, 75, 76]),
        );
        callbackBindings.terminalVtWrite(terminal, enquiry);
        expect(allocator.allocations, hasLength(warmed));
        expect(allocator.freeCounts, isEmpty);
        callbackBindings.terminalSetOnEnquiry(
          terminal,
          () => Uint8List.fromList([90]),
        );
        callbackBindings.terminalVtWrite(terminal, enquiry);
        expect(allocator.sizes.values.last, 1);
        expect(allocator.allocations, hasLength(warmed + 1));
        expect(allocator.freeCounts.values, [1]);
        expect(replies, [
          [65, 66, 67, 68],
          [69, 70, 71, 72],
          [73, 74, 75, 76],
          [90],
        ]);
        callbackBindings.terminalSetOnEnquiry(terminal, null);
        expect(allocator.freeCounts.values, everyElement(1));
        expect(
          allocator.freeCounts.keys.toSet(),
          allocator.allocations.keys.toSet(),
        );
      },
    );

    test('reuses empty reply storage and frees it with the terminal', () {
      final allocator = _FailingCallbackAllocator();
      addTearDown(allocator.dispose);
      final callbackBindings = FfiTerminalBindings(
        callbackAllocator: allocator,
      );
      final terminal = callbackBindings.terminalNew(8, 4);
      try {
        callbackBindings.terminalSetOnEnquiry(terminal, () => Uint8List(0));
        final enquiry = Uint8List.fromList([5]);
        callbackBindings.terminalVtWrite(terminal, enquiry);
        final warmed = allocator.allocations.length;
        callbackBindings.terminalVtWrite(terminal, enquiry);
        expect(allocator.allocations, hasLength(warmed));
        expect(allocator.sizes.values.last, 1);
        expect(allocator.freeCounts, isEmpty);
      } finally {
        callbackBindings.terminalFree(terminal);
      }
      expect(allocator.freeCounts.values, everyElement(1));
      expect(
        allocator.freeCounts.keys.toSet(),
        allocator.allocations.keys.toSet(),
      );
    });

    test('copies VT input and exposes updated selector state', () {
      final terminal = createTerminal();

      bindings.terminalVtWrite(terminal, Uint8List.fromList('abc'.codeUnits));

      expect(bindings.terminalGetCursorX(terminal), 3);
      expect(bindings.terminalGetCursorY(terminal), 0);
      expect(
        bindings.terminalGetActiveScreen(terminal),
        TerminalScreen.primary,
      );
    });

    test('writes through ground and reports partial consumption', () {
      final terminal = createTerminal();

      bindings.terminalVtWrite(terminal, Uint8List.fromList([0x1b, 0x5b]));

      expect(
        bindings.terminalWriteUntilGround(
          terminal,
          Uint8List.fromList('31mA'.codeUnits),
        ),
        3,
      );
      bindings.terminalVtWrite(terminal, Uint8List.fromList([0x1b, 0x5b]));
      expect(
        bindings.terminalWriteUntilGround(
          terminal,
          Uint8List.fromList('31'.codeUnits),
        ),
        isNull,
      );
    });

    test('copies binary unknown sequence callback data', () {
      final terminal = createTerminal();
      TerminalUnknownSequence? sequence;
      bindings.terminalSetUnknownSequenceMaxBytes(terminal, 2);
      bindings.terminalSetOnUnknownSequence(
        terminal,
        (value) => sequence = value,
      );

      bindings.terminalVtWrite(
        terminal,
        Uint8List.fromList([0x1b, 0x5f, 0x00, 0x01, 0x02, 0x1b, 0x5c]),
      );

      expect(sequence?.tag, TerminalUnknownSequenceTag.apc);
      expect(sequence?.content, Uint8List.fromList([0x00, 0x01]));
      expect(sequence?.truncated, isTrue);
    });

    test('maps terminfo byte-limit failures', () {
      final terminal = createTerminal();

      expect(
        () => bindings.terminalSetTerminfoName(terminal, 'a' * 129),
        throwsA(isA<InvalidValueException>()),
      );
    });

    test('rethrows callback failures after the native operation completes', () {
      final terminal = createTerminal();
      final failure = StateError('callback failure');
      bindings.terminalSetOnBell(terminal, () => throw failure);

      expect(
        () => bindings.terminalVtWrite(terminal, Uint8List.fromList([7])),
        throwsA(same(failure)),
      );
      expect(bindings.terminalGetVtProcessingError(terminal), isFalse);
    });

    test('rejects output queries for an invalid terminal handle', () {
      expect(
        () => bindings.terminalGetGeometry(const .fromAddress(0)),
        throwsA(isA<LibGhosttyException>()),
      );
    });
  });
}

final class _FailingCallbackAllocator implements Allocator {
  final failure = StateError('forced callback allocation failure');
  final allocations = <int, Pointer<NativeType>>{};
  final freeCounts = <int, int>{};
  final sizes = <int, int>{};
  var failNext = false;

  @override
  Pointer<T> allocate<T extends NativeType>(int byteCount, {int? alignment}) {
    if (failNext) {
      failNext = false;
      throw failure;
    }
    final pointer = calloc.allocate<T>(byteCount, alignment: alignment);
    allocations[pointer.address] = pointer;
    sizes[pointer.address] = byteCount;
    return pointer;
  }

  @override
  void free(Pointer<NativeType> pointer) {
    freeCounts.update(pointer.address, (count) => count + 1, ifAbsent: () => 1);
  }

  void dispose() {
    for (final pointer in allocations.values) {
      calloc.free(pointer);
    }
  }
}

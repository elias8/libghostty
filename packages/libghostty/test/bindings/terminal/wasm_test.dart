@Tags(['wasm'])
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:libghostty/src/bindings/terminal/wasm.dart';
import 'package:libghostty/src/bindings/wasm/adapter.dart';
import 'package:libghostty/src/bindings/wasm/layouts.dart';
import 'package:libghostty/src/bindings/wasm/memory.dart';
import 'package:libghostty/src/generated/libghostty_enums.g.dart';
import 'package:libghostty/src/types/types.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

import '../helpers/wasm_binding_fixture.dart';

void main() {
  final fixture = WasmBindingFixture();
  late Layouts layout;

  setUpAll(() async {
    await fixture.load();
    layout = fixture.layout;
  });

  tearDownAll(fixture.close);

  group('WasmTerminalBindings', () {
    group('terminalPaste', () {
      test(
        'paste owns one block and releases it after retry and rejection',
        () {
          final harness = FaultExports()..poisonAllocations = true;
          final table = web.Table(
            web.TableDescriptor(element: 'anyfunc', initial: 0),
          );
          harness.object['__indirect_function_table'] = table;
          final memory = Memory(harness.exports);
          var accepted = true;
          harness.object['ghostty_terminal_paste'] =
              (JSNumber _, JSNumber paste, JSNumber written) {
                expect(paste.toDartInt % 4, 0);
                expect(memory.readU8(written.toDartInt), 0);
                final mimes = memory.readPtr(
                  paste.toDartInt + layout.pasteMimes,
                );
                expect(mimes % 4, 0);
                expect(memory.readU32(mimes + layout.stringLen), 10);
                expect(memory.readBytes(memory.readPtr(mimes), 10), [
                  116,
                  101,
                  120,
                  116,
                  47,
                  112,
                  108,
                  97,
                  105,
                  110,
                ]);
                if (accepted) memory.writeU8(written.toDartInt, 1);
                return Result.success.value.toJS;
              }.toJS;
          final bindings = WasmTerminalBindings(harness.exports, layout);

          harness.failAt = harness.attempts + 1;

          expect(
            () => bindings.terminalPaste(
              const .fromAddress(7),
              PasteRequest.text('retry me'),
            ),
            throwsA(isA<OutOfMemoryException>()),
          );
          expect(harness.frees, isEmpty);

          harness.failAt = null;
          expect(
            bindings.terminalPaste(
              const .fromAddress(7),
              PasteRequest.text('retry me'),
            ),
            isTrue,
          );
          expect(harness.allocations, hasLength(1));
          expect(harness.frees, harness.allocations);

          accepted = false;
          expect(
            bindings.terminalPaste(
              const .fromAddress(7),
              PasteRequest.text('retry me'),
            ),
            isFalse,
          );
          expect(harness.allocations, hasLength(2));
          expect(harness.frees, harness.allocations);
        },
      );

      test(
        'MIME reader isolates reentrant writes and releases failed storage',
        () {
          final harness = FaultExports();
          final table = web.Table(
            web.TableDescriptor(element: 'anyfunc', initial: 1),
          );
          harness.object['__indirect_function_table'] = table;
          final memory = Memory(harness.exports);
          late PasteSink borrowed;
          var nested = false;
          var writes = 0;
          var chunks = [
            Uint8List.fromList([1, 2, 3]),
          ];
          late Uint8List outerBytes;
          late Uint8List nestedBytes;
          table.set(
            0,
            wrapJsAsWasmFunction(
              (JSNumber _, JSNumber pointer, JSNumber length) {
                writes++;
                if (nested) {
                  expect(
                    memory.readBytes(pointer.toDartInt, length.toDartInt),
                    [4, 5],
                  );
                  nestedBytes.buffer.toJS.callMethod<JSArrayBuffer>(
                    'transfer'.toJS,
                  );
                  expect(nestedBytes.length, 0);
                } else {
                  expect(
                    memory.readBytes(pointer.toDartInt, length.toDartInt),
                    outerBytes,
                  );
                  nested = true;
                  try {
                    nestedBytes = Uint8List.fromList([4, 5]);
                    expect(borrowed.write(nestedBytes), isTrue);
                  } finally {
                    nested = false;
                  }
                  expect(
                    memory.readBytes(pointer.toDartInt, length.toDartInt),
                    outerBytes,
                  );
                }
                return 1.toJS;
              }.toJS,
              ['i32', 'i32', 'i32'],
              ['i32'],
            ),
          );
          memory.writePtr(128 + layout.writerWrite, 0);
          memory.writePtr(128 + layout.writerUserdata, 0);
          harness.object['ghostty_terminal_paste'] =
              (JSNumber _, JSNumber paste, JSNumber written) {
                final reader = memory.readU32(
                  paste.toDartInt + layout.pasteReader,
                );
                final mime = memory.readPtr(
                  paste.toDartInt + layout.pasteMimes,
                );
                final accepted =
                    (table.get(reader)! as JSFunction).callAsFunction(
                          null,
                          0.toJS,
                          mime.toJS,
                          128.toJS,
                        )!
                        as JSNumber;
                memory.writeU8(written.toDartInt, accepted.toDartInt);
                return Result.success.value.toJS;
              }.toJS;
          final bindings = WasmTerminalBindings(harness.exports, layout);
          final request = PasteRequest.mime(
            source: .text,
            mimes: const ['text/plain'],
            read: (_, sink) {
              borrowed = sink;
              for (final bytes in chunks) {
                outerBytes = bytes;
                if (!sink.write(bytes)) return false;
              }
              return true;
            },
          );

          expect(
            bindings.terminalPaste(const .fromAddress(7), request),
            isTrue,
          );

          expect(writes, 2);
          expect(harness.frees, unorderedEquals(harness.allocations));
          expect(() => borrowed.write(Uint8List(0)), throwsStateError);

          harness.failAt = harness.attempts + 2;
          expect(
            () => bindings.terminalPaste(const .fromAddress(7), request),
            throwsA(isA<OutOfMemoryException>()),
          );
          expect(harness.frees, unorderedEquals(harness.allocations));
          expect(
            () => borrowed.write(Uint8List.fromList([6])),
            throwsStateError,
          );

          harness.failAt = null;
          expect(
            bindings.terminalPaste(const .fromAddress(7), request),
            isTrue,
          );
          expect(writes, 4);
          expect(harness.frees, unorderedEquals(harness.allocations));

          harness.failAt = harness.attempts + 3;
          expect(
            () => bindings.terminalPaste(const .fromAddress(7), request),
            throwsA(isA<OutOfMemoryException>()),
          );
          expect(writes, 5);
          expect(harness.frees, unorderedEquals(harness.allocations));
          expect(() => borrowed.write(Uint8List(0)), throwsStateError);

          harness.failAt = null;
          chunks = [
            Uint8List.fromList([1, 2, 3]),
            Uint8List.fromList([1, 2, 3, 4, 5, 6, 7]),
            Uint8List.fromList([8, 9]),
          ];
          final allocationCount = harness.allocations.length;

          expect(
            bindings.terminalPaste(const .fromAddress(7), request),
            isTrue,
          );
          expect(writes, 11);
          expect(
            harness.allocations
                .skip(allocationCount + 1)
                .map((value) => value.$2),
            [3, 2, 7, 2, 2],
          );
          expect(harness.frees, unorderedEquals(harness.allocations));
        },
      );

      test('paste dispatcher restores readers and releases nested slots', () {
        final harness = FaultExports();
        final memory = Memory(harness.exports);
        final table = web.Table(
          web.TableDescriptor(element: 'anyfunc', initial: 1, maximum: 3),
        );
        harness.object['__indirect_function_table'] = table;
        final output = <int, List<int>>{};
        table.set(
          0,
          wrapJsAsWasmFunction(
            (int id, int pointer, int length) {
              output
                  .putIfAbsent(id, () => [])
                  .addAll(memory.readBytes(pointer, length));
              return 1;
            }.toJS,
            ['i32', 'i32', 'i32'],
            ['i32'],
          ),
        );
        var depth = 0;
        JSFunction? cachedReader;
        harness.object['ghostty_terminal_paste'] =
            (JSNumber terminal, JSNumber paste, JSNumber written) {
              final readerIndex = memory.readU32(
                paste.toDartInt + layout.pasteReader,
              );
              final reader = table.get(readerIndex)! as JSFunction;
              cachedReader = reader;
              final writer = 128 + depth * 32;
              memory.writePtr(writer + layout.writerWrite, 0);
              memory.writePtr(
                writer + layout.writerUserdata,
                terminal.toDartInt,
              );
              final mime = memory.readPtr(paste.toDartInt + layout.pasteMimes);
              depth++;
              try {
                final accepted =
                    reader.callAsFunction(null, 0.toJS, mime.toJS, writer.toJS)!
                        as JSNumber;
                memory.writeU8(written.toDartInt, accepted.toDartInt);
              } finally {
                depth--;
              }
              return Result.success.value.toJS;
            }.toJS;
        final bindings = WasmTerminalBindings(harness.exports, layout);
        final failure = StateError('reader failed');

        PasteRequest mime(bool Function(PasteSink) read) => PasteRequest.mime(
          source: .text,
          mimes: const ['text/plain'],
          read: (_, sink) => read(sink),
        );

        bool paste(int id, PasteRequest request) =>
            bindings.terminalPaste(.fromAddress(id), request);

        void expectReleased() {
          for (var index = 1; index < table.length; index++) {
            expect(table.get(index), isNull);
          }
          expect(
            (cachedReader!.callAsFunction(null, 0.toJS, 0.toJS, 0.toJS)!
                    as JSNumber)
                .toDartInt,
            0,
          );
          expect(harness.frees, unorderedEquals(harness.allocations));
        }

        expect(paste(7, PasteRequest.text('\x01')), isTrue);
        expectReleased();

        expect(
          () => paste(7, mime((_) => throw failure)),
          throwsA(same(failure)),
        );
        expectReleased();

        expect(
          paste(7, mime((sink) => sink.write(Uint8List.fromList([2])))),
          isTrue,
        );
        expectReleased();

        expect(
          paste(
            7,
            mime((outer) {
              expect(outer.write(Uint8List.fromList([3])), isTrue);
              expect(
                paste(
                  8,
                  mime((inner) {
                    expect(
                      () => paste(9, PasteRequest.text('unregistered')),
                      throwsA(anything),
                    );
                    expect(outer.write(Uint8List.fromList([4])), isTrue);
                    return inner.write(Uint8List.fromList([9]));
                  }),
                ),
                isTrue,
              );
              expect(paste(8, PasteRequest.text('\n')), isTrue);
              expect(
                () => paste(8, mime((_) => throw failure)),
                throwsA(same(failure)),
              );
              return outer.write(Uint8List.fromList([5]));
            }),
          ),
          isTrue,
        );
        expect(output, {
          7: [1, 2, 3, 4, 5],
          8: [9, 10],
        });
        expect(table.length, 3);
        expectReleased();
      });

      test('paste table growth failure releases transfer storage', () {
        final harness = FaultExports();
        final table = web.Table(
          web.TableDescriptor(element: 'anyfunc', initial: 0, maximum: 0),
        );
        harness.object['__indirect_function_table'] = table;
        final bindings = WasmTerminalBindings(harness.exports, layout);
        var reads = 0;
        final request = PasteRequest.mime(
          source: .text,
          mimes: const ['text/plain'],
          read: (_, _) {
            reads++;
            return true;
          },
        );

        for (var attempt = 0; attempt < 2; attempt++) {
          expect(
            () => bindings.terminalPaste(const .fromAddress(7), request),
            throwsA(anything),
          );
          expect(reads, 0);
          expect(table.length, 0);
          expect(harness.frees, unorderedEquals(harness.allocations));
        }
      });
    });

    group('terminalVtWrite', () {
      test('large terminal writes reuse storage and preserve bytes', () {
        final harness = FaultExports();
        harness.object['__indirect_function_table'] = web.Table(
          web.TableDescriptor(element: 'anyfunc', initial: 0),
        );
        final memory = Memory(harness.exports);
        final payload = Uint8List(128 * 1024)..last = 0x5a;
        var writes = 0;
        harness.object['ghostty_terminal_vt_write'] =
            (JSNumber _, JSNumber pointer, JSNumber length) {
              expect(
                memory.readBytes(pointer.toDartInt, length.toDartInt),
                payload,
              );
              writes++;
            }.toJS;
        final bindings = WasmTerminalBindings(harness.exports, layout);

        bindings.terminalVtWrite(const .fromAddress(7), payload);
        final allocations = harness.allocations.length;

        bindings.terminalVtWrite(const .fromAddress(7), payload);

        expect(writes, 2);
        expect(harness.allocations, hasLength(allocations));
        expect(harness.frees, isEmpty);
      });
    });

    group('terminalSetOnEnquiry', () {
      test('reply buffers reuse exact sizes and preserve storage on OOM', () {
        final harness = FaultExports();
        final table = web.Table(
          web.TableDescriptor(element: 'anyfunc', initial: 0),
        );
        harness.object['__indirect_function_table'] = table;
        final memory = Memory(harness.exports);
        var callbackIndex = 0;
        harness.object['ghostty_terminal_set'] =
            (JSNumber _, JSNumber _, JSNumber pointer) {
              callbackIndex = pointer.toDartInt;
              return Result.success.value.toJS;
            }.toJS;
        harness.object['ghostty_terminal_free'] = ((JSNumber _) {}).toJS;
        final bindings = WasmTerminalBindings(harness.exports, layout);
        var reply = Uint8List.fromList([1, 2, 3]);
        bindings.terminalSetOnEnquiry(const .fromAddress(7), () => reply);

        void invoke() {
          (table.get(callbackIndex)! as JSFunction).callAsFunction(
            null,
            64.toJS,
            7.toJS,
            0.toJS,
          );
        }

        invoke();
        final firstPointer = memory.readU32(64);
        final allocations = harness.allocations.length;
        invoke();

        expect(harness.allocations, hasLength(allocations));
        expect(memory.readU32(64), firstPointer);

        reply = Uint8List(0);
        invoke();
        final emptyPointer = memory.readU32(64);
        expect(memory.readU32(64 + layout.stringLen), 0);
        expect(harness.allocations.last, (emptyPointer, 1));
        expect(harness.frees, contains((firstPointer, 3)));

        final emptyAllocations = harness.allocations.length;
        invoke();

        expect(harness.allocations, hasLength(emptyAllocations));

        harness.failAt = harness.attempts + 1;
        reply = Uint8List.fromList([4, 5]);
        invoke();

        expect(memory.readU32(64), 0);
        expect(memory.readU32(64 + layout.stringLen), 0);
        expect(harness.frees, isNot(contains((emptyPointer, 1))));

        harness.failAt = null;

        reply = Uint8List(0);
        invoke();

        expect(memory.readU32(64), emptyPointer);

        bindings.terminalFree(const .fromAddress(7));
        expect(harness.frees, contains((emptyPointer, 1)));
      });

      test('self clear frees reply storage only after native consumption', () {
        final harness = FaultExports();
        final table = web.Table(
          web.TableDescriptor(element: 'anyfunc', initial: 0),
        );
        harness.object['__indirect_function_table'] = table;
        final memory = Memory(harness.exports);
        var callbackIndex = 0;
        harness.object['ghostty_terminal_set'] =
            (JSNumber _, JSNumber _, JSNumber index) {
              callbackIndex = index.toDartInt;
              return Result.success.value.toJS;
            }.toJS;
        harness.object['ghostty_terminal_free'] = ((JSNumber _) {}).toJS;
        late (int, int) replyAllocation;
        harness.object['ghostty_terminal_vt_write'] =
            (JSNumber _, JSNumber _, JSNumber _) {
              final callback = table.get(callbackIndex)! as JSFunction;
              callback.callAsFunction(null, 64.toJS, 7.toJS, 0.toJS);
              final pointer = memory.readU32(64);
              final length = memory.readU32(64 + layout.stringLen);
              replyAllocation = (pointer, length);
              expect(memory.readBytes(pointer, length), [1, 2, 3]);
              expect(harness.frees, isNot(contains(replyAllocation)));
            }.toJS;
        final bindings = WasmTerminalBindings(harness.exports, layout);
        bindings.terminalSetOnEnquiry(const .fromAddress(7), () {
          bindings.terminalSetOnEnquiry(const .fromAddress(7), null);
          return Uint8List.fromList([1, 2, 3]);
        });

        bindings.terminalVtWrite(
          const .fromAddress(7),
          Uint8List.fromList([5]),
        );

        expect(
          harness.frees.where((value) => value == replyAllocation),
          hasLength(1),
        );

        bindings.terminalFree(const .fromAddress(7));
        expect(
          harness.frees.where((value) => value == replyAllocation),
          hasLength(1),
        );
      });
    });
  });
}

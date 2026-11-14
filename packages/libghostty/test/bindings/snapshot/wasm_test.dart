@Tags(['wasm'])
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:libghostty/libghostty.dart'
    show SnapshotImageProgress, SnapshotPageProgress;
import 'package:libghostty/src/bindings/snapshot/wasm.dart';
import 'package:libghostty/src/bindings/types.dart';
import 'package:libghostty/src/bindings/wasm/memory.dart';
import 'package:libghostty/src/generated/libghostty_enums.g.dart';
import 'package:test/test.dart';

import '../helpers/wasm_binding_fixture.dart';

void main() {
  test('decodes page and image progress before reporting completion', () {
    final harness = FaultExports();
    final memory = Memory(harness.exports);
    var event = -1;
    harness.object['ghostty_snapshot_decoder_next'] = (JSNumber _) {
      event++;
      return (event < 2 ? Result.success : Result.noValue).value.toJS;
    }.toJS;
    harness.object['ghostty_snapshot_decoder_get'] =
        (JSNumber _, JSNumber data, JSNumber out) {
          if (data.toDartInt != SnapshotDecoderData.progressKind.value) {
            return Result.invalidValue.value.toJS;
          }
          memory.writeU32(out.toDartInt, event);
          return Result.success.value.toJS;
        }.toJS;
    harness.object['ghostty_snapshot_decoder_get_multi'] =
        (
              JSNumber _,
              JSNumber count,
              JSNumber keys,
              JSNumber values,
              JSNumber written,
            ) {
              final fields = event == 0
                  ? <int, int>{
                      SnapshotDecoderData.progressScreen.value:
                          TerminalScreen.primary.value,
                      SnapshotDecoderData.progressRows.value: 12,
                      SnapshotDecoderData.progressRemaining.value: 2,
                    }
                  : <int, int>{
                      SnapshotDecoderData.progressScreen.value:
                          TerminalScreen.alternate.value,
                      SnapshotDecoderData.progressImageId.value: 42,
                      SnapshotDecoderData.progressImageFrame.value: 3,
                      SnapshotDecoderData.progressImageBytes.value: 768,
                    };
              if (count.toDartInt != fields.length) {
                return Result.invalidValue.value.toJS;
              }
              for (var i = 0; i < count.toDartInt; i++) {
                final key = memory.readU32(keys.toDartInt + i * 4);
                final value = fields[key];
                if (value == null) return Result.invalidValue.value.toJS;
                memory.writeU32(
                  memory.readPtr(values.toDartInt + i * 4),
                  value,
                );
              }
              memory.writeU32(written.toDartInt, count.toDartInt);
              return Result.success.value.toJS;
            }
            .toJS;

    final bindings = WasmSnapshotBindings(harness.exports);
    const decoder = LibGhosttyHandle.fromAddress(64);
    final page = bindings.snapshotDecoderNext(decoder)! as SnapshotPageProgress;
    expect(
      (page.screen, page.rows, page.remaining),
      (TerminalScreen.primary, 12, 2),
    );
    final image =
        bindings.snapshotDecoderNext(decoder)! as SnapshotImageProgress;
    expect(
      (image.screen, image.imageId, image.frame, image.bytes),
      (TerminalScreen.alternate, 42, 3, 768),
    );
    expect(bindings.snapshotDecoderNext(decoder), isNull);
  });
}

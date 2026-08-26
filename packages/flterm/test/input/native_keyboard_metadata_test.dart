import 'package:flterm/src/input/native_keyboard_metadata.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('newest native record wins after an unmatched redispatch', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final store = NativeKeyboardMetadataStore.instance..ensureInitialized();
    final received = <NativeKeyboardMetadata>[];
    bool capture(KeyEvent event) {
      if (event.physicalKey == PhysicalKeyboardKey.keyA) {
        final metadata = store.forEvent(event);
        if (metadata != null) received.add(metadata);
      }
      return false;
    }

    HardwareKeyboard.instance.addHandler(capture);
    addTearDown(() => HardwareKeyboard.instance.removeHandler(capture));

    final keyData = KeyEventSimulator.getKeyData(
      LogicalKeyboardKey.keyA,
      platform: 'linux',
      physicalKey: PhysicalKeyboardKey.keyA,
      character: 'a',
    );

    Future<void> sendMetadata({
      required int eventTime,
      required int unshiftedCodepoint,
      bool down = true,
    }) async {
      final message = <String, Object?>{
        'platform': 'linux',
        'scanCode': keyData['scanCode']! as int,
        'keyCode': keyData['keyCode']! as int,
        'down': down,
        'eventTime': eventTime,
        'mods': 0,
        'consumedMods': 0,
        'unshiftedCodepoint': unshiftedCodepoint,
        'textWithoutAlt': null,
        'deadKey': false,
      };
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'dev.flterm/native_keyboard',
        const StandardMessageCodec().encodeMessage(message),
        (_) {},
      );
    }

    await sendMetadata(eventTime: 1, unshiftedCodepoint: 0x71);
    await simulateKeyDownEvent(
      LogicalKeyboardKey.keyA,
      platform: 'linux',
      physicalKey: PhysicalKeyboardKey.keyA,
      character: 'a',
    );
    await simulateKeyUpEvent(
      LogicalKeyboardKey.keyA,
      platform: 'linux',
      physicalKey: PhysicalKeyboardKey.keyA,
    );

    // A native redispatch can arrive without a second Flutter key event.
    await sendMetadata(eventTime: 1, unshiftedCodepoint: 0x71);
    await sendMetadata(eventTime: 2, unshiftedCodepoint: 0x7A);
    await simulateKeyDownEvent(
      LogicalKeyboardKey.keyA,
      platform: 'linux',
      physicalKey: PhysicalKeyboardKey.keyA,
      character: 'a',
    );
    await simulateKeyUpEvent(
      LogicalKeyboardKey.keyA,
      platform: 'linux',
      physicalKey: PhysicalKeyboardKey.keyA,
    );

    // A raw key-up without a regularized KeyEvent can also leave a stale
    // second-stage record. The next complete tap must use newer metadata.
    await sendMetadata(eventTime: 3, unshiftedCodepoint: 0x78, down: false);
    final orphanUp = <String, dynamic>{...keyData, 'type': 'keyup'};
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.keyEvent.name,
      SystemChannels.keyEvent.codec.encodeMessage(orphanUp),
      (_) {},
    );
    await sendMetadata(eventTime: 4, unshiftedCodepoint: 0x62);
    await simulateKeyDownEvent(
      LogicalKeyboardKey.keyA,
      platform: 'linux',
      physicalKey: PhysicalKeyboardKey.keyA,
      character: 'a',
    );
    await sendMetadata(eventTime: 5, unshiftedCodepoint: 0x63, down: false);
    await simulateKeyUpEvent(
      LogicalKeyboardKey.keyA,
      platform: 'linux',
      physicalKey: PhysicalKeyboardKey.keyA,
    );

    debugDefaultTargetPlatformOverride = null;
    expect(received, hasLength(4));
    expect(received.first.unshiftedCodepoint, 0x71);
    expect(received[1].unshiftedCodepoint, 0x7A);
    expect(received[2].unshiftedCodepoint, 0x62);
    expect(received.last.unshiftedCodepoint, 0x63);
  });
}

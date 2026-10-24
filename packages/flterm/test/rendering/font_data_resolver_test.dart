import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flterm/src/rendering/font/font_data_resolver.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(FontDataResolver.clearCache);
  tearDown(() {
    messenger.setMockMessageHandler('flutter/assets', null);
    FontDataResolver.clearCache();
  });

  test(
    'concurrent resolutions share one asset load and successful bytes',
    () async {
      final asset = Completer<ByteData?>();
      final paths = <String>[];
      messenger.setMockMessageHandler('flutter/assets', (message) {
        paths.add(
          utf8.decode(
            message!.buffer.asUint8List(
              message.offsetInBytes,
              message.lengthInBytes,
            ),
          ),
        );
        return asset.future;
      });
      final first = FontDataResolver.resolve('__FltermConcurrentFamily__');
      final second = FontDataResolver.resolve('__FltermConcurrentFamily__');
      expect(identical(first, second), isTrue);
      asset.complete(ByteData.sublistView(Uint8List.fromList([1, 2, 3])));
      expect(await first, orderedEquals([1, 2, 3]));
      expect(await second, orderedEquals([1, 2, 3]));
      expect(
        await FontDataResolver.resolve('__FltermConcurrentFamily__'),
        orderedEquals([1, 2, 3]),
      );
      expect(paths, ['assets/fonts/__FltermConcurrentFamily__-Regular.ttf']);
    },
  );

  test('clearing while pending keeps the new result cached', () async {
    final old = Completer<ByteData?>();
    var requests = 0;
    messenger.setMockMessageHandler('flutter/assets', (_) {
      requests++;
      if (requests == 1) return old.future;
      return Future.value(ByteData.sublistView(Uint8List.fromList([9])));
    });
    final stale = FontDataResolver.resolve('__FltermClearFamily__');
    FontDataResolver.clearCache();
    expect(
      await FontDataResolver.resolve('__FltermClearFamily__'),
      orderedEquals([9]),
    );
    old.complete(ByteData.sublistView(Uint8List.fromList([1])));
    expect(await stale, orderedEquals([1]));
    expect(
      await FontDataResolver.resolve('__FltermClearFamily__'),
      orderedEquals([9]),
    );
    expect(requests, 2);
  });

  test('a missing asset result stays cached on the next lookup', () async {
    var available = false;
    var requests = 0;
    messenger.setMockMessageHandler('flutter/assets', (_) async {
      requests++;
      if (!available) return null;
      return ByteData.sublistView(Uint8List.fromList([7]));
    });
    expect(await FontDataResolver.resolve('__FltermMissingFamily__'), isNull);
    final firstLookupRequests = requests;
    expect(firstLookupRequests, greaterThan(0));
    available = true;
    expect(await FontDataResolver.resolve('__FltermMissingFamily__'), isNull);
    expect(requests, firstLookupRequests);
  });
}

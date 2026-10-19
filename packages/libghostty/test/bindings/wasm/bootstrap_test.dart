@Tags(['wasm'])
library;

import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

void main() {
  group('initializeForWeb', () {
    test('throws StateError for an unsuccessful HTTP status', () async {
      final channel = spawnHybridUri('/test/helpers/asset_server.dart');
      addTearDown(channel.sink.close);
      final port = (await channel.stream.first as double).toInt();
      final wasmUri = Uri.parse(
        'http://localhost:$port/lib/src/wasm/missing.wasm',
      );

      await expectLater(
        initializeForWeb(wasmUri),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('HTTP 404'),
          ),
        ),
      );
    });

    test('retries the same URI after an HTTP failure', () async {
      final channel = spawnHybridUri('/test/helpers/asset_server.dart');
      addTearDown(channel.sink.close);
      final port = (await channel.stream.first as double).toInt();
      final uri = Uri.parse('http://localhost:$port/missing.wasm');
      for (var attempt = 0; attempt < 2; attempt++) {
        await expectLater(
          initializeForWeb(uri),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('HTTP 404'),
            ),
          ),
        );
      }
    });

    test('rejects a conflicting URI while loading the artifact', () async {
      final channel = spawnHybridUri('/test/helpers/asset_server.dart');
      addTearDown(channel.sink.close);
      final port = (await channel.stream.first as double).toInt();
      final wasmUri = Uri.parse(
        'http://localhost:$port/lib/src/wasm/libghostty.wasm',
      );
      final conflictingUri = Uri.parse(
        'http://localhost:$port/lib/src/wasm/other.wasm',
      );
      final initialization = initializeForWeb(wasmUri);

      expect(
        () => initializeForWeb(conflictingUri),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('already in progress'),
          ),
        ),
      );

      expect(identical(initializeForWeb(wasmUri), initialization), isTrue);
      await initialization;
    });
  });
}

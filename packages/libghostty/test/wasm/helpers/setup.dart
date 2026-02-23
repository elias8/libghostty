import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

Future<void> setUpWasm() async {
  final channel = spawnHybridUri('/test/wasm/helpers/asset_server.dart');
  final port = (await channel.stream.first as double).toInt();
  final wasmUri = Uri.parse(
    'http://localhost:$port/lib/src/wasm/ghostty-vt.wasm',
  );
  await initializeForWeb(wasmUri);
}

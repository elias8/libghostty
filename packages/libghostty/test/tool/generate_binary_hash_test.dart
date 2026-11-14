@TestOn('vm')
library;

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

void main() {
  test('generates hashes and metadata for the current source pin', () async {
    final script = File('tool/generate_binary_hash.dart').absolute.path;
    final packageConfig = File(
      '../../.dart_tool/package_config.json',
    ).absolute.path;
    final tmp = Directory.systemTemp.createTempSync('generate_hashes_test_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    const commit = '9fff23493f87a2a9a9b56b29dca45e27d5adf27e';
    File('${tmp.path}/ghostty.version').writeAsStringSync('$commit\n');
    final artifacts = Directory('${tmp.path}/artifacts')..createSync();
    final binary = File('${artifacts.path}/libghostty-test.so')
      ..writeAsBytesSync([1, 2, 3]);

    final result = await Process.run(
      'dart',
      ['--packages=$packageConfig', script, artifacts.path, 'libghostty-v1'],
      workingDirectory: tmp.path,
      runInShell: Platform.isWindows,
    );

    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    final generated = File(
      '${tmp.path}/lib/src/hook/asset_hashes.dart',
    ).readAsStringSync();
    expect(generated, contains("const prebuiltGhosttyCommit = '$commit';"));
    expect(generated, contains("const releaseTag = 'libghostty-v1';"));
    expect(
      generated,
      contains(sha256.convert(binary.readAsBytesSync()).toString()),
    );
  });
}

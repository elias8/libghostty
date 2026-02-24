@Tags(['ffi'])
library;

import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:libghostty/src/hook/library_provider.dart';
import 'package:test/test.dart';

import 'helpers/test_server.dart';

BuildInput createTestBuildInput({
  OS os = OS.macOS,
  Architecture arch = Architecture.arm64,
  required Uri outputDirectoryShared,
}) {
  final tmp = Directory.systemTemp.createTempSync('build_input_test_');
  addTearDown(() => tmp.deleteSync(recursive: true));

  return BuildInput(<String, dynamic>{
    'package_name': 'test_package',
    'package_root': tmp.path,
    'out_dir': '${tmp.path}/out',
    'out_dir_shared': outputDirectoryShared.path,
    'user_defines': <String, String>{},
    'config': <String, dynamic>{
      'build_code_assets': true,
      'build_asset_types': <String>[],
      'extensions': <String, dynamic>{
        'code_assets': <String, dynamic>{
          'target_os': os.name,
          'target_architecture': arch.name,
          'ios': <String, dynamic>{'target_sdk': 'iphoneos'},
        },
      },
    },
  });
}

void main() {
  group('DownloadPrebuilt', () {
    late Directory tmpDir;
    late Directory serverDir;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('download_prebuilt_test_');
      serverDir = Directory('${tmpDir.path}/server')..createSync();
    });

    tearDown(() => tmpDir.deleteSync(recursive: true));

    DownloadPrebuilt createProvider({
      OS os = OS.macOS,
      Architecture arch = Architecture.arm64,
      required TestServer server,
    }) {
      final input = createTestBuildInput(
        os: os,
        arch: arch,
        outputDirectoryShared: Uri.directory('${tmpDir.path}/cache/'),
      );
      return DownloadPrebuilt(input, baseUrl: server.baseUrl.toString());
    }

    void seedBinary(List<int> content) {
      const releaseTag = 'v0.0.1-dev.1';
      const zigTarget = 'aarch64-macos';
      const ext = 'dylib';
      const fileName = 'libghostty-$releaseTag-$zigTarget.$ext';

      Directory('${serverDir.path}/$releaseTag').createSync(recursive: true);
      File('${serverDir.path}/$releaseTag/$fileName').writeAsBytesSync(content);
    }

    test('downloads binary from server to target', () async {
      final content = [0xCA, 0xFE, 0xBA, 0xBE];
      seedBinary(content);
      final server = await TestServer.start(serverDir);
      addTearDown(server.close);

      final target = File('${tmpDir.path}/output/lib/target.dylib');
      await createProvider(server: server).provide(target);

      expect(target.existsSync(), isTrue);
      expect(target.readAsBytesSync(), equals(content));
    });

    test('caches downloaded binary', () async {
      final content = [1, 2, 3, 4, 5];
      seedBinary(content);
      final server = await TestServer.start(serverDir);
      addTearDown(server.close);

      final provider = createProvider(server: server);
      final target1 = File('${tmpDir.path}/output1/lib/t.dylib');
      final target2 = File('${tmpDir.path}/output2/lib/t.dylib');

      await provider.provide(target1);

      serverDir.deleteSync(recursive: true);
      serverDir.createSync();

      await provider.provide(target2);

      expect(target2.readAsBytesSync(), equals(content));
    });

    test('skips hash validation when no hash registered', () async {
      final content = [10, 20, 30];
      seedBinary(content);
      final server = await TestServer.start(serverDir);
      addTearDown(server.close);

      final target = File('${tmpDir.path}/output/lib/t.dylib');
      await createProvider(server: server).provide(target);

      expect(target.existsSync(), isTrue);
    });

    test('passes with correct hash', () async {
      final content = [0xDE, 0xAD];
      seedBinary(content);
      final server = await TestServer.start(serverDir);
      addTearDown(server.close);

      final target = File('${tmpDir.path}/output/lib/t.dylib');
      await createProvider(server: server).provide(target);

      expect(target.existsSync(), isTrue);
    });

    test('uses cached file when available', () async {
      const releaseTag = 'v0.0.1-dev.1';
      const zigTarget = 'aarch64-macos';
      const ext = 'dylib';
      const fileName = 'libghostty-$releaseTag-$zigTarget.$ext';

      final cacheDir = Directory('${tmpDir.path}/cache/prebuilt-$releaseTag')
        ..createSync(recursive: true);
      final cachedContent = [0xFF, 0xFF];
      File('${cacheDir.path}/$fileName').writeAsBytesSync(cachedContent);

      final server = await TestServer.start(serverDir);
      addTearDown(server.close);

      final target = File('${tmpDir.path}/output/lib/t.dylib');

      await createProvider(server: server).provide(target);

      expect(target.readAsBytesSync(), equals(cachedContent));
    });

    test('creates parent directories for target', () async {
      seedBinary([1]);
      final server = await TestServer.start(serverDir);
      addTearDown(server.close);

      final target = File('${tmpDir.path}/a/b/c/d/target.dylib');
      await createProvider(server: server).provide(target);

      expect(target.existsSync(), isTrue);
    });

    test('throws with actionable message on HTTP 404', () async {
      final server = await TestServer.start(serverDir);
      addTearDown(server.close);

      final target = File('${tmpDir.path}/output/lib/t.dylib');

      expect(
        () => createProvider(server: server).provide(target),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            allOf(contains('Failed to download'), contains('HTTP 404')),
          ),
        ),
      );
    });
  });
}

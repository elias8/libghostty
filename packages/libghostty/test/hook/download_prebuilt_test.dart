@Tags(['ffi'])
library;

import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:crypto/crypto.dart';
import 'package:libghostty/src/hook/ghostty_source.dart';
import 'package:libghostty/src/hook/library_provider.dart';
import 'package:libghostty/src/hook/platform.dart';
import 'package:test/test.dart';

import 'helpers/test_server.dart';

void main() {
  group('DownloadPrebuilt', () {
    late Directory tmpDir;
    late Directory serverDir;
    late Uri packageRoot;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('download_prebuilt_test_');
      serverDir = Directory('${tmpDir.path}/server')..createSync();
      packageRoot = Uri.directory('${tmpDir.path}/pkg/');
      Directory.fromUri(packageRoot).createSync(recursive: true);
      File.fromUri(
        packageRoot.resolve('ghostty.version'),
      ).writeAsStringSync('861a9cf537a58a380bc6a0784573b3de3a70415e\n');
    });

    tearDown(() {
      tmpDir.deleteSync(recursive: true);
    });

    DownloadPrebuilt createProvider({
      OS os = OS.macOS,
      Architecture arch = Architecture.arm64,
      Map<String, String>? hashes,
      required TestServer server,
    }) {
      return DownloadPrebuilt(
        targetOS: os,
        targetArch: arch,
        packageRoot: packageRoot,
        cacheBase: Uri.directory('${tmpDir.path}/cache/'),
        baseUrl: server.baseUrl.toString(),
        hashes: hashes,
      );
    }

    void seedBinary(List<int> content) {
      final commit = pinnedCommit(packageRoot);
      final commitShort = commit.substring(0, 7);
      final platform = platformKey(OS.macOS, Architecture.arm64);
      final ext = libraryExtension(OS.macOS);
      final fileName = 'libghostty-vt-$commitShort-$platform.$ext';

      Directory('${serverDir.path}/v$commit').createSync(recursive: true);
      File('${serverDir.path}/v$commit/$fileName').writeAsBytesSync(content);
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
      await createProvider(hashes: {}, server: server).provide(target);

      expect(target.existsSync(), isTrue);
    });

    test('passes with correct hash', () async {
      final content = [0xDE, 0xAD];
      seedBinary(content);
      final server = await TestServer.start(serverDir);
      addTearDown(server.close);

      final commitShort = pinnedCommit(packageRoot).substring(0, 7);
      final platform = platformKey(OS.macOS, Architecture.arm64);
      final expectedHash = sha256.convert(content).toString();

      final target = File('${tmpDir.path}/output/lib/t.dylib');
      await createProvider(
        hashes: {'$commitShort-$platform': expectedHash},
        server: server,
      ).provide(target);

      expect(target.existsSync(), isTrue);
    });

    test('rejects binary with wrong hash', () async {
      final content = [0xBA, 0xAD];
      seedBinary(content);
      final server = await TestServer.start(serverDir);
      addTearDown(server.close);

      final commitShort = pinnedCommit(packageRoot).substring(0, 7);
      final platform = platformKey(OS.macOS, Architecture.arm64);

      final target = File('${tmpDir.path}/output/lib/t.dylib');

      expect(
        () => createProvider(
          hashes: {'$commitShort-$platform': 'wrong_hash_value'},
          server: server,
        ).provide(target),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('SHA256 hash mismatch'),
          ),
        ),
      );
    });

    test('re-downloads when cached file has wrong hash', () async {
      final commitShort = pinnedCommit(packageRoot).substring(0, 7);
      final platform = platformKey(OS.macOS, Architecture.arm64);
      final ext = libraryExtension(OS.macOS);
      final fileName = 'libghostty-vt-$commitShort-$platform.$ext';

      final cacheDir = Directory('${tmpDir.path}/cache/prebuilt-$commitShort')
        ..createSync(recursive: true);
      File('${cacheDir.path}/$fileName').writeAsBytesSync([0xFF]);

      final correctContent = [0xCA, 0xFE];
      seedBinary(correctContent);
      final server = await TestServer.start(serverDir);
      addTearDown(server.close);

      final expectedHash = sha256.convert(correctContent).toString();
      final target = File('${tmpDir.path}/output/lib/t.dylib');

      await createProvider(
        hashes: {'$commitShort-$platform': expectedHash},
        server: server,
      ).provide(target);

      expect(target.readAsBytesSync(), equals(correctContent));
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
            allOf(
              contains('Failed to download'),
              contains('Install Zig'),
              contains('LIBGHOSTTY_PREBUILT'),
            ),
          ),
        ),
      );
    });

    test('leaves no partial files after download failure', () async {
      final server = await TestServer.start(serverDir);
      addTearDown(server.close);

      final target = File('${tmpDir.path}/output/lib/t.dylib');

      await expectLater(
        () => createProvider(server: server).provide(target),
        throwsA(isA<Exception>()),
      );

      final cacheEntries = Directory('${tmpDir.path}/cache')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.tmp'));

      expect(cacheEntries, isEmpty);
    });
  });
}

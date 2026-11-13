@Tags(['ffi'])
library;

import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:crypto/crypto.dart';
import 'package:hooks/hooks.dart';
import 'package:libghostty/src/hook/asset_hashes.dart'
    show prebuiltGhosttyCommit, releaseTag;
import 'package:libghostty/src/hook/library_provider.dart';
import 'package:test/test.dart';

import 'helpers/test_server.dart';

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
      Map<String, String>? hashes,
      required TestServer server,
    }) {
      final input = createTestBuildInput(
        os: os,
        arch: arch,
        outputDirectoryShared: Uri.directory('${tmpDir.path}/cache/'),
      );
      return DownloadPrebuilt(
        input,
        baseUrl: server.baseUrl.toString(),
        hashes: hashes,
      );
    }

    const binaryName = 'libghostty-aarch64-macos.dylib';

    void seedBinary(List<int> content) {
      Directory('${serverDir.path}/$releaseTag').createSync(recursive: true);
      File(
        '${serverDir.path}/$releaseTag/$binaryName',
      ).writeAsBytesSync(content);
    }

    Map<String, String> hashFor(List<int> content) {
      return {binaryName: sha256.convert(content).toString()};
    }

    group('provide', () {
      test(
        'rejects cached binaries built from another Ghostty commit',
        () async {
          final input = createTestBuildInput(
            outputDirectoryShared: Uri.directory('${tmpDir.path}/cache/'),
          );
          File.fromUri(
            input.packageRoot.resolve('ghostty.version'),
          ).writeAsStringSync('different-commit');
          final cacheDir = Directory(
            '${tmpDir.path}/cache/prebuilt-$releaseTag',
          )..createSync(recursive: true);
          final content = [0xCA, 0xFE];
          File('${cacheDir.path}/$binaryName').writeAsBytesSync(content);
          final target = File('${tmpDir.path}/output/lib/target.dylib');
          final provider = DownloadPrebuilt(input, hashes: hashFor(content));

          await expectLater(provider.provide(target), throwsStateError);
          expect(target.existsSync(), isFalse);
        },
      );

      test('downloads binary from server to target', () async {
        final content = [0xCA, 0xFE, 0xBA, 0xBE];
        seedBinary(content);
        final server = await TestServer.start(serverDir);
        addTearDown(server.close);

        final target = File('${tmpDir.path}/output/lib/target.dylib');
        await createProvider(
          hashes: hashFor(content),
          server: server,
        ).provide(target);

        expect(target.existsSync(), isTrue);
        expect(target.readAsBytesSync(), equals(content));
      });

      test('caches downloaded binary', () async {
        final content = [1, 2, 3, 4, 5];
        seedBinary(content);
        final server = await TestServer.start(serverDir);
        addTearDown(server.close);

        final provider = createProvider(
          hashes: hashFor(content),
          server: server,
        );
        final target1 = File('${tmpDir.path}/output1/lib/t.dylib');
        final target2 = File('${tmpDir.path}/output2/lib/t.dylib');

        await provider.provide(target1);
        await server.close();
        await provider.provide(target2);

        expect(target2.readAsBytesSync(), equals(content));
      });

      test('throws when target has no registered hash', () async {
        final content = [10, 20, 30];
        seedBinary(content);
        final server = await TestServer.start(serverDir);
        addTearDown(server.close);

        final target = File('${tmpDir.path}/output/lib/t.dylib');

        expect(
          () => createProvider(hashes: {}, server: server).provide(target),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('No known hash for'),
            ),
          ),
        );
      });

      test('accepts matching hash', () async {
        final content = [0xDE, 0xAD];
        seedBinary(content);
        final server = await TestServer.start(serverDir);
        addTearDown(server.close);

        final expectedHash = sha256.convert(content).toString();

        final target = File('${tmpDir.path}/output/lib/t.dylib');
        await createProvider(
          hashes: {'libghostty-aarch64-macos.dylib': expectedHash},
          server: server,
        ).provide(target);

        expect(target.existsSync(), isTrue);
      });

      test('throws on hash mismatch', () async {
        final content = [0xDE, 0xAD];
        seedBinary(content);
        final server = await TestServer.start(serverDir);
        addTearDown(server.close);

        final target = File('${tmpDir.path}/output/lib/t.dylib');

        expect(
          () => createProvider(
            hashes: {'libghostty-aarch64-macos.dylib': 'wrong-hash'},
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

      test('uses cached file when available', () async {
        final cacheDir = Directory('${tmpDir.path}/cache/prebuilt-$releaseTag')
          ..createSync(recursive: true);
        final cachedContent = [0xFF, 0xFF];
        File('${cacheDir.path}/$binaryName').writeAsBytesSync(cachedContent);

        final server = await TestServer.start(serverDir);
        addTearDown(server.close);

        final target = File('${tmpDir.path}/output/lib/t.dylib');

        await createProvider(
          hashes: hashFor(cachedContent),
          server: server,
        ).provide(target);

        expect(target.readAsBytesSync(), equals(cachedContent));
      });

      test('creates parent directories for target', () async {
        final content = [1];
        seedBinary(content);
        final server = await TestServer.start(serverDir);
        addTearDown(server.close);

        final target = File('${tmpDir.path}/a/b/c/d/target.dylib');
        await createProvider(
          hashes: hashFor(content),
          server: server,
        ).provide(target);

        expect(target.existsSync(), isTrue);
      });

      test('throws with HTTP status in message', () async {
        final server = await TestServer.start(serverDir);
        addTearDown(server.close);

        final target = File('${tmpDir.path}/output/lib/t.dylib');

        expect(
          () => createProvider(hashes: {}, server: server).provide(target),
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
  });
}

BuildInput createTestBuildInput({
  OS os = OS.macOS,
  Architecture arch = Architecture.arm64,
  required Uri outputDirectoryShared,
}) {
  final tmp = Directory.systemTemp.createTempSync('build_input_test_');
  addTearDown(() => tmp.deleteSync(recursive: true));
  File('${tmp.path}/ghostty.version').writeAsStringSync(prebuiltGhosttyCommit);

  return BuildInput(<String, dynamic>{
    'package_name': 'test_package',
    'package_root': '${tmp.path}/',
    'out_dir': '${tmp.path}/out',
    'out_dir_shared': outputDirectoryShared.toFilePath(),
    'user_defines': <String, String>{},
    'config': <String, dynamic>{
      'build_code_assets': true,
      'build_asset_types': <String>['code_assets/code'],
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

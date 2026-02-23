@Tags(['ffi'])
library;

import 'dart:io';

import 'package:test/test.dart';

import '../../hook/src/ghostty_source.dart';
import 'helpers/test_server.dart';

void main() {
  group('pinnedCommit', () {
    test('is a 40-character hex string', () {
      final tmpDir = Directory.systemTemp.createTempSync('pinnedCommit_test_');
      addTearDown(() => tmpDir.deleteSync(recursive: true));
      File(
        '${tmpDir.path}/ghostty.version',
      ).writeAsStringSync('861a9cf537a58a380bc6a0784573b3de3a70415e\n');

      final commit = pinnedCommit(tmpDir.uri);
      expect(commit, hasLength(40));
      expect(commit, matches(RegExp(r'^[0-9a-f]{40}$')));
    });

    test('throws when ghostty.version is missing', () {
      final tmpDir = Directory.systemTemp.createTempSync('pinnedCommit_test_');
      addTearDown(() => tmpDir.deleteSync(recursive: true));

      expect(() => pinnedCommit(tmpDir.uri), throwsA(isA<StateError>()));
    });
  });

  group('resolveSource', () {
    late Directory tmpDir;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('ghostty_source_test_');
    });

    tearDown(() {
      tmpDir.deleteSync(recursive: true);
    });

    test(
      'returns local ghostty/ dir when it exists at workspace root',
      () async {
        final packageRoot = Directory(
          '${tmpDir.path}/workspace/packages/libghostty',
        )..createSync(recursive: true);
        final ghosttyDir = Directory('${tmpDir.path}/workspace/ghostty')
          ..createSync(recursive: true);
        File('${ghosttyDir.path}/build.zig').writeAsStringSync('marker');

        final result = await resolveSource(
          packageRoot: packageRoot.uri,
          cacheBase: Uri.directory('${tmpDir.path}/cache/'),
        );

        expect(result.path, contains('workspace/ghostty'));
      },
    );

    test('resolved local dir contains expected files', () async {
      final packageRoot = Directory(
        '${tmpDir.path}/workspace/packages/libghostty',
      )..createSync(recursive: true);
      final ghosttyDir = Directory('${tmpDir.path}/workspace/ghostty')
        ..createSync(recursive: true);
      File('${ghosttyDir.path}/build.zig').writeAsStringSync('marker');

      final result = await resolveSource(
        packageRoot: packageRoot.uri,
        cacheBase: Uri.directory('${tmpDir.path}/cache/'),
      );

      expect(File('${result.path}/build.zig').existsSync(), isTrue);
    });

    test('falls back to local dir when GHOSTTY_SRC is not set', () async {
      final packageRoot = Directory(
        '${tmpDir.path}/workspace/packages/libghostty',
      )..createSync(recursive: true);
      Directory('${tmpDir.path}/workspace/ghostty').createSync(recursive: true);

      final result = await resolveSource(
        packageRoot: packageRoot.uri,
        cacheBase: Uri.directory('${tmpDir.path}/cache/'),
      );

      expect(result.existsSync(), isTrue);
    });
  });

  group('downloadSource', () {
    late Directory tmpDir;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('download_source_test_');
    });

    tearDown(() {
      tmpDir.deleteSync(recursive: true);
    });

    late Uri packageRoot;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('download_source_test_');
      packageRoot = Uri.directory('${tmpDir.path}/pkg/');
      Directory.fromUri(packageRoot).createSync(recursive: true);
      File.fromUri(
        packageRoot.resolve('ghostty.version'),
      ).writeAsStringSync('861a9cf537a58a380bc6a0784573b3de3a70415e\n');
    });

    test('extracts tarball content to cache', () async {
      final contentDir = Directory('${tmpDir.path}/content')..createSync();
      File('${contentDir.path}/build.zig').writeAsStringSync('test marker');

      final tarball = File('${tmpDir.path}/test.tar.gz');
      Process.runSync('tar', ['czf', tarball.path, '-C', contentDir.path, '.']);

      final serverDir = Directory('${tmpDir.path}/server')..createSync();
      tarball.copySync('${serverDir.path}/source.tar.gz');

      final server = await TestServer.start(serverDir);
      addTearDown(server.close);

      final cacheBase = Uri.directory('${tmpDir.path}/cache/');
      final result = await downloadSource(
        cacheBase,
        packageRoot: packageRoot,
        tarballUrl: '${server.baseUrl}/source.tar.gz',
      );

      expect(
        File('${result.path}/build.zig').readAsStringSync(),
        equals('test marker'),
      );
    });

    test('returns cached directory on second call', () async {
      final contentDir = Directory('${tmpDir.path}/content')..createSync();
      File('${contentDir.path}/marker.txt').writeAsStringSync('v1');

      final tarball = File('${tmpDir.path}/test.tar.gz');
      Process.runSync('tar', ['czf', tarball.path, '-C', contentDir.path, '.']);

      final serverDir = Directory('${tmpDir.path}/server')..createSync();
      tarball.copySync('${serverDir.path}/source.tar.gz');

      final server = await TestServer.start(serverDir);
      addTearDown(server.close);

      final cacheBase = Uri.directory('${tmpDir.path}/cache/');
      final tarballUrl = '${server.baseUrl}/source.tar.gz';

      final first = await downloadSource(
        cacheBase,
        packageRoot: packageRoot,
        tarballUrl: tarballUrl,
      );

      File('${serverDir.path}/source.tar.gz').deleteSync();

      final second = await downloadSource(
        cacheBase,
        packageRoot: packageRoot,
        tarballUrl: tarballUrl,
      );

      expect(second.path, equals(first.path));
      expect(
        File('${second.path}/marker.txt').readAsStringSync(),
        equals('v1'),
      );
    });

    test('throws on HTTP error with actionable message', () async {
      final serverDir = Directory('${tmpDir.path}/empty_server')..createSync();
      final server = await TestServer.start(serverDir);
      addTearDown(server.close);

      final cacheBase = Uri.directory('${tmpDir.path}/cache/');

      expect(
        () => downloadSource(
          cacheBase,
          packageRoot: packageRoot,
          tarballUrl: '${server.baseUrl}/nonexistent.tar.gz',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            allOf(contains('Failed to download'), contains('GHOSTTY_SRC')),
          ),
        ),
      );
    });

    test('cleans up cache dir on extraction failure', () async {
      final serverDir = Directory('${tmpDir.path}/server')..createSync();
      File('${serverDir.path}/bad.tar.gz').writeAsBytesSync([0x00, 0x01, 0x02]);

      final server = await TestServer.start(serverDir);
      addTearDown(server.close);

      final cacheBase = Uri.directory('${tmpDir.path}/cache/');

      await expectLater(
        () => downloadSource(
          cacheBase,
          packageRoot: packageRoot,
          tarballUrl: '${server.baseUrl}/bad.tar.gz',
        ),
        throwsA(isA<Exception>()),
      );

      final commit = pinnedCommit(packageRoot);
      final cacheDir = Directory.fromUri(
        cacheBase.resolve('ghostty-source-${commit.substring(0, 12)}-none/'),
      );
      expect(cacheDir.existsSync(), isFalse);
    });

    test('cleans up tarball after successful extraction', () async {
      final contentDir = Directory('${tmpDir.path}/content')..createSync();
      File('${contentDir.path}/file.txt').writeAsStringSync('data');

      final tarball = File('${tmpDir.path}/test.tar.gz');
      Process.runSync('tar', ['czf', tarball.path, '-C', contentDir.path, '.']);

      final serverDir = Directory('${tmpDir.path}/server')..createSync();
      tarball.copySync('${serverDir.path}/source.tar.gz');

      final server = await TestServer.start(serverDir);
      addTearDown(server.close);

      final cacheBase = Uri.directory('${tmpDir.path}/cache/');
      await downloadSource(
        cacheBase,
        packageRoot: packageRoot,
        tarballUrl: '${server.baseUrl}/source.tar.gz',
      );

      final commit = pinnedCommit(packageRoot);
      final tarballInCache = File.fromUri(cacheBase.resolve('$commit.tar.gz'));
      expect(tarballInCache.existsSync(), isFalse);
    });
  });
}

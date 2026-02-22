@Tags(['ffi'])
library;

import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:test/test.dart';

import '../../hook/src/library_provider.dart';

void main() {
  group('PrebuiltLocal', () {
    late Directory tmpDir;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('prebuilt_local_test_');
    });

    tearDown(() {
      tmpDir.deleteSync(recursive: true);
    });

    test('copies source file to target', () async {
      final source = File('${tmpDir.path}/source.dylib')
        ..writeAsBytesSync([0xDE, 0xAD, 0xBE, 0xEF]);
      final target = File('${tmpDir.path}/output/lib/target.dylib');

      await PrebuiltLocal(source.path).provide(target);

      expect(target.existsSync(), isTrue);
      expect(target.readAsBytesSync(), equals([0xDE, 0xAD, 0xBE, 0xEF]));
    });

    test('creates parent directories for target', () async {
      final source = File('${tmpDir.path}/source.dylib')
        ..writeAsBytesSync([1, 2, 3]);
      final target = File('${tmpDir.path}/deep/nested/dir/target.dylib');

      await PrebuiltLocal(source.path).provide(target);

      expect(target.existsSync(), isTrue);
    });

    test('throws when source file does not exist', () {
      final target = File('${tmpDir.path}/target.dylib');

      expect(
        () => const PrebuiltLocal('/nonexistent/path.dylib').provide(target),
        throwsA(isA<Exception>()),
      );
    });

    test('error message includes the missing path', () {
      final target = File('${tmpDir.path}/target.dylib');
      const missingPath = '/does/not/exist/lib.dylib';

      expect(
        () => const PrebuiltLocal(missingPath).provide(target),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains(missingPath),
          ),
        ),
      );
    });
  });

  group('zigAvailable', () {
    test('returns a boolean', () {
      expect(LibraryProvider.zigAvailable(), isA<bool>());
    });
  });

  group('sourceAvailable', () {
    late Directory tmpDir;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('source_available_test_');
    });

    tearDown(() {
      tmpDir.deleteSync(recursive: true);
    });

    test('returns true when ghostty/ exists at workspace root', () {
      final packageRoot = Directory(
        '${tmpDir.path}/workspace/packages/libghostty',
      )..createSync(recursive: true);
      Directory('${tmpDir.path}/workspace/ghostty')
          .createSync(recursive: true);

      expect(LibraryProvider.sourceAvailable(packageRoot.uri), isTrue);
    });

    test('returns false when ghostty/ does not exist', () {
      final packageRoot = Directory(
        '${tmpDir.path}/workspace/packages/libghostty',
      )..createSync(recursive: true);

      expect(LibraryProvider.sourceAvailable(packageRoot.uri), isFalse);
    });
  });

  group('sealed class', () {
    test('pattern match covers all subtypes', () {
      String describe(LibraryProvider p) {
        return switch (p) {
          PrebuiltLocal() => 'prebuilt',
          CompileFromSource() => 'compile',
          DownloadPrebuilt() => 'download',
        };
      }

      expect(describe(const PrebuiltLocal('/tmp/lib.dylib')), 'prebuilt');
      expect(
        describe(
          DownloadPrebuilt(
            targetOS: OS.macOS,
            targetArch: Architecture.arm64,
            cacheBase: Uri.directory('/tmp/'),
          ),
        ),
        'download',
      );
    });

    test('all subtypes are LibraryProvider', () {
      expect(const PrebuiltLocal('/tmp/lib.dylib'), isA<LibraryProvider>());
      expect(
        DownloadPrebuilt(
          targetOS: OS.macOS,
          targetArch: Architecture.arm64,
          cacheBase: Uri.directory('/tmp/'),
        ),
        isA<LibraryProvider>(),
      );
    });
  });
}

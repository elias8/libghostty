import 'dart:io';

import 'package:flterm/src/rendering/font/font_data_resolver_io.dart'
    show trySystemFonts;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('trySystemFonts', () {
    late Directory fonts;

    setUp(() {
      fonts = Directory.systemTemp.createTempSync('flterm-fonts-');
      addTearDown(() => fonts.deleteSync(recursive: true));
    });

    group('font lookup', () {
      test('returns a direct candidate before recursive matches', () {
        File('${fonts.path}/Family-Regular.ttf').writeAsBytesSync([1]);
        final nested = Directory('${fonts.path}/family')..createSync();
        File('${nested.path}/family-fallback.ttf').writeAsBytesSync([2]);

        final result = IOOverrides.runWithIOOverrides(
          () =>
              trySystemFonts('Family', (_) => ['Family-Regular.ttf'], const {}),
          _FontDirectoryOverrides(fonts.path),
        );

        expect(result, orderedEquals([1]));
      });

      test(
        'returns a recursively discovered font with an accepted extension',
        () {
          final nested = Directory('${fonts.path}/family')..createSync();
          File('${nested.path}/family-regular.otf').writeAsBytesSync([3]);

          final result = IOOverrides.runWithIOOverrides(
            () => trySystemFonts('Family', (_) => const [], const {}),
            _FontDirectoryOverrides(fonts.path),
          );

          expect(result, orderedEquals([3]));
        },
      );

      test('skips recursively discovered fonts with excluded weights', () {
        final nested = Directory('${fonts.path}/family')..createSync();
        File('${nested.path}/family-bold.ttf').writeAsBytesSync([4]);

        final result = IOOverrides.runWithIOOverrides(
          () => trySystemFonts('Family', (_) => const [], const {'bold'}),
          _FontDirectoryOverrides(fonts.path),
        );

        expect(result, isNull);
      });

      test('returns null when no font matches the family', () {
        final result = IOOverrides.runWithIOOverrides(
          () => trySystemFonts(
            '__FltermMissingFamily__',
            (_) => const [],
            const {},
          ),
          _FontDirectoryOverrides(fonts.path),
        );

        expect(result, isNull);
      });

      test('propagates a direct candidate read failure', () {
        final overrides = _FontDirectoryOverrides(
          fonts.path,
          unreadableCandidate: 'Family-Regular.ttf',
        );

        expect(
          () => IOOverrides.runWithIOOverrides(
            () => trySystemFonts(
              'Family',
              (_) => ['Family-Regular.ttf'],
              const {},
            ),
            overrides,
          ),
          throwsA(
            isA<FileSystemException>().having(
              (error) => error.message,
              'message',
              'read failed',
            ),
          ),
        );
      });

      test('ignores a recursive listing failure', () {
        final inaccessible = File('${fonts.path}/fonts')..createSync();

        final result = IOOverrides.runWithIOOverrides(
          () => trySystemFonts('Family', (_) => const [], const {}),
          _FontDirectoryOverrides(inaccessible.path, unreadableDirectory: true),
        );

        expect(result, isNull);
      });
    });
  });
}

final class _FontDirectoryOverrides extends IOOverrides {
  final String fontsPath;

  final String? unreadableCandidate;
  final bool unreadableDirectory;
  _FontDirectoryOverrides(
    this.fontsPath, {
    this.unreadableCandidate,
    this.unreadableDirectory = false,
  });

  @override
  Directory createDirectory(String path) {
    if (unreadableDirectory) return _UnreadableDirectory(fontsPath);
    return super.createDirectory(fontsPath);
  }

  @override
  File createFile(String path) {
    if (unreadableCandidate != null && path.endsWith(unreadableCandidate!)) {
      return _UnreadableFile(path);
    }
    return super.createFile(path);
  }
}

final class _UnreadableDirectory implements Directory {
  @override
  final String path;

  _UnreadableDirectory(this.path);

  @override
  bool existsSync() => true;

  @override
  List<FileSystemEntity> listSync({
    bool recursive = false,
    bool followLinks = true,
  }) => throw const FileSystemException('list failed');

  @override
  Never noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('unused directory operation');
}

final class _UnreadableFile implements File {
  @override
  final String path;

  _UnreadableFile(this.path);

  @override
  bool existsSync() => true;

  @override
  Never noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('unused file operation');

  @override
  Never readAsBytesSync() => throw const FileSystemException('read failed');
}

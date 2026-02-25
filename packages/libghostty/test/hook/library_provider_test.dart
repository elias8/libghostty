@Tags(['ffi'])
library;

import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:libghostty/src/hook/library_provider.dart';
import 'package:test/test.dart';

BuildInput createTestBuildInput({
  OS os = OS.macOS,
  Architecture arch = Architecture.arm64,
}) {
  final tmp = Directory.systemTemp.createTempSync('build_input_test_');
  addTearDown(() => tmp.deleteSync(recursive: true));

  return BuildInput(<String, dynamic>{
    'package_name': 'test_package',
    'package_root': tmp.path,
    'out_dir': '${tmp.path}/out',
    'out_dir_shared': '${tmp.path}/shared',
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
  group('zigAvailable', () {
    test('returns a boolean', () {
      expect(LibraryProvider.zigAvailable(), isA<bool>());
    });
  });

  group('sealed class', () {
    test('pattern match covers all subtypes', () {
      String describe(LibraryProvider p) {
        return switch (p) {
          CompileFromSource() => 'compile',
          DownloadPrebuilt() => 'download',
        };
      }

      expect(describe(DownloadPrebuilt(createTestBuildInput())), 'download');
    });

    test('all subtypes are LibraryProvider', () {
      expect(DownloadPrebuilt(createTestBuildInput()), isA<LibraryProvider>());
    });
  });

  group('libraryExtension', () {
    test('maps OS to native library file extension', () {
      expect(libraryExtension(OS.macOS), 'dylib');
      expect(libraryExtension(OS.iOS), 'dylib');
      expect(libraryExtension(OS.windows), 'dll');
      expect(libraryExtension(OS.linux), 'so');
      expect(libraryExtension(OS.android), 'so');
    });
  });
}

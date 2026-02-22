@Tags(['ffi'])
library;

import 'package:code_assets/code_assets.dart';
import 'package:test/test.dart';

import '../../hook/src/platform.dart';

void main() {
  group('platformKey', () {
    test('maps supported OS and architecture combinations', () {
      expect(platformKey(OS.macOS, Architecture.arm64), 'macos-arm64');
      expect(platformKey(OS.macOS, Architecture.x64), 'macos-x64');
      expect(platformKey(OS.linux, Architecture.x64), 'linux-x64');
      expect(platformKey(OS.linux, Architecture.arm64), 'linux-arm64');
      expect(platformKey(OS.linux, Architecture.arm), 'linux-arm');
      expect(platformKey(OS.linux, Architecture.ia32), 'linux-ia32');
      expect(platformKey(OS.windows, Architecture.x64), 'windows-x64');
      expect(platformKey(OS.iOS, Architecture.arm64), 'ios-arm64');
      expect(platformKey(OS.android, Architecture.arm64), 'android-arm64');
    });

    test('throws for unsupported OS', () {
      expect(
        () => platformKey(OS.fuchsia, Architecture.arm64),
        throwsA(isA<Exception>()),
      );
    });

    test('throws for unsupported architecture', () {
      expect(
        () => platformKey(OS.linux, Architecture.riscv64),
        throwsA(isA<Exception>()),
      );
    });

    test('error message suggests Zig for unsupported OS', () {
      expect(
        () => platformKey(OS.fuchsia, Architecture.arm64),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Install Zig'),
          ),
        ),
      );
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

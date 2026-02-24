@Tags(['ffi'])
library;

import 'package:code_assets/code_assets.dart';
import 'package:libghostty/src/hook/zig_target.dart';
import 'package:test/test.dart';

void main() {
  group('zigTarget', () {
    group('iOS', () {
      test('arm64 device produces aarch64-ios', () {
        final target = zigTarget(
          OS.iOS,
          Architecture.arm64,
          iOSSdk: IOSSdk.iPhoneOS,
        );
        expect(target, 'aarch64-ios');
      });

      test('arm64 simulator produces aarch64-ios-simulator', () {
        final target = zigTarget(
          OS.iOS,
          Architecture.arm64,
          iOSSdk: IOSSdk.iPhoneSimulator,
        );
        expect(target, 'aarch64-ios-simulator');
      });

      test('x64 simulator produces x86_64-ios-simulator', () {
        final target = zigTarget(
          OS.iOS,
          Architecture.x64,
          iOSSdk: IOSSdk.iPhoneSimulator,
        );
        expect(target, 'x86_64-ios-simulator');
      });

      test('defaults to device when iOSSdk is null', () {
        final target = zigTarget(OS.iOS, Architecture.arm64);
        expect(target, 'aarch64-ios');
      });
    });

    group('Android', () {
      test('arm64 produces aarch64-linux-android', () {
        final target = zigTarget(OS.android, Architecture.arm64);
        expect(target, 'aarch64-linux-android');
      });

      test('x64 produces x86_64-linux-android', () {
        final target = zigTarget(OS.android, Architecture.x64);
        expect(target, 'x86_64-linux-android');
      });

      test('arm produces arm-linux-android', () {
        final target = zigTarget(OS.android, Architecture.arm);
        expect(target, 'arm-linux-android');
      });

      test('ia32 produces x86-linux-android', () {
        final target = zigTarget(OS.android, Architecture.ia32);
        expect(target, 'x86-linux-android');
      });
    });

    group('desktop', () {
      test('macOS arm produces arm-macos', () {
        final target = zigTarget(OS.macOS, Architecture.arm);
        expect(target, 'arm-macos');
      });

      test('linux arm produces arm-linux', () {
        final target = zigTarget(OS.linux, Architecture.arm);
        expect(target, 'arm-linux');
      });

      test('windows arm produces arm-windows', () {
        final target = zigTarget(OS.windows, Architecture.arm);
        expect(target, 'arm-windows');
      });
    });

    group('host target', () {
      test('returns null for current OS and architecture', () {
        final target = zigTarget(OS.current, Architecture.current);
        expect(target, isNull);
      });
    });

    group('unsupported', () {
      test('throws for unsupported OS', () {
        expect(
          () => zigTarget(OS.fuchsia, Architecture.arm64),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws for unsupported architecture', () {
        expect(
          () => zigTarget(OS.linux, Architecture.riscv64),
          throwsA(isA<ArgumentError>()),
        );
      });
    });
  });
}

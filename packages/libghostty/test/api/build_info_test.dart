import 'package:libghostty/libghostty.dart';
import 'package:libghostty/src/bindings/bindings.dart';
import 'package:libghostty/src/generated/libghostty_enums.g.dart'
    show BuildInfo;
import 'package:test/test.dart';

import '../helpers/setup.dart';

void main() {
  setUp(() => testEnvironment);

  group('LibGhosttyBuildInfo', () {
    group('instance', () {
      test('returns consistent singleton', () {
        final a = LibGhosttyBuildInfo.instance;
        final b = LibGhosttyBuildInfo.instance;
        expect(identical(a, b), isTrue);
      });
    });

    test(
      'reports the loaded library version and semantic version components',
      () {
        final info = LibGhosttyBuildInfo.instance;
        expect(LibGhostty.version, info.versionString);
        final version =
            '${info.versionMajor}.${info.versionMinor}.${info.versionPatch}'
            '${info.versionPre.isEmpty ? '' : '-${info.versionPre}'}'
            '${info.versionBuild.isEmpty ? '' : '+${info.versionBuild}'}';
        expect(LibGhostty.version, version);
      },
    );

    test('reports each feature from the loaded library', () {
      final info = LibGhosttyBuildInfo.instance;
      final features = <BuildInfo, bool>{
        BuildInfo.featureSnapshot: info.featureSnapshot,
        BuildInfo.featureFormatter: info.featureFormatter,
        BuildInfo.featureSelection: info.featureSelection,
        BuildInfo.featureSearch: info.featureSearch,
        BuildInfo.featureRenderState: info.featureRenderState,
        BuildInfo.featureInputEncode: info.featureInputEncode,
        BuildInfo.featureColor: info.featureColor,
        BuildInfo.featureGridIntrospection: info.featureGridIntrospection,
        BuildInfo.featureGlyphProtocol: info.featureGlyphProtocol,
      };
      for (final feature in features.entries) {
        expect(
          feature.value,
          bindings.utility.buildInfoBool(feature.key),
          reason: feature.key.name,
        );
      }
      if (isBrowser) expect(info.kittyGraphics, isFalse);
    });

    group('fields', () {
      test('return typed values', () {
        final info = LibGhosttyBuildInfo.instance;
        expect(info.simd, isA<bool>());
        expect(info.kittyGraphics, isA<bool>());
        expect(info.tmuxControlMode, isA<bool>());
        expect(info.optimizeMode, isA<OptimizeMode>());
        expect(info.versionString, isNotEmpty);
        expect(info.versionMajor, greaterThanOrEqualTo(0));
        expect(info.versionMinor, greaterThanOrEqualTo(0));
        expect(info.versionPatch, greaterThanOrEqualTo(0));
        expect(info.versionBuild, isA<String>());
      });
    });
  });
}

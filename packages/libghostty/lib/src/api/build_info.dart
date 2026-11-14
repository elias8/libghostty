import '../bindings/bindings.dart';
import '../generated/libghostty_enums.g.dart';

/// Compile-time build configuration of the native libghostty library.
///
/// These values reflect the options the library was built with and are
/// constant for the lifetime of the process. Access via the [instance]
/// singleton.
///
/// ```dart
/// final info = LibGhosttyBuildInfo.instance;
/// print('${info.versionString} (${info.optimizeMode})');
/// print('SIMD: ${info.simd}, Kitty graphics: ${info.kittyGraphics}');
/// ```
final class LibGhosttyBuildInfo {
  /// Singleton instance. All values are populated once on first access.
  static final instance = LibGhosttyBuildInfo._();

  /// Whether SIMD-accelerated code paths are enabled in the native library.
  final bool simd;

  /// Whether Kitty graphics protocol support is available in the native
  /// library.
  final bool kittyGraphics;

  /// Whether tmux control mode support is available in the native library.
  final bool tmuxControlMode;

  /// Whether the snapshot feature is enabled.
  final bool featureSnapshot;

  /// Whether the formatter feature is enabled.
  final bool featureFormatter;

  /// Whether the selection feature is enabled.
  final bool featureSelection;

  /// Whether the search feature is enabled.
  final bool featureSearch;

  /// Whether the render state feature is enabled.
  final bool featureRenderState;

  /// Whether the input encoding feature is enabled.
  final bool featureInputEncode;

  /// Whether the color feature is enabled.
  final bool featureColor;

  /// Whether the grid introspection feature is enabled.
  final bool featureGridIntrospection;

  /// Whether the glyph protocol feature is enabled.
  final bool featureGlyphProtocol;

  /// Optimization mode the library was built with (debug, release-safe,
  /// release-small, or release-fast).
  final OptimizeMode optimizeMode;

  /// Full version string (e.g. "1.2.3" or "1.2.3-dev+abcdef").
  final String versionString;

  /// Major version number.
  final int versionMajor;

  /// Minor version number.
  final int versionMinor;

  /// Patch version number.
  final int versionPatch;

  /// Pre-release metadata string. Empty if no pre-release metadata is present.
  final String versionPre;

  /// Build metadata string (e.g. commit hash). Empty if no build metadata
  /// is present.
  final String versionBuild;

  LibGhosttyBuildInfo._()
    : simd = _getBool(.simd),
      kittyGraphics = _getBool(.kittyGraphics),
      tmuxControlMode = _getBool(.tmuxControlMode),
      featureSnapshot = _getBool(.featureSnapshot),
      featureFormatter = _getBool(.featureFormatter),
      featureSelection = _getBool(.featureSelection),
      featureSearch = _getBool(.featureSearch),
      featureRenderState = _getBool(.featureRenderState),
      featureInputEncode = _getBool(.featureInputEncode),
      featureColor = _getBool(.featureColor),
      featureGridIntrospection = _getBool(.featureGridIntrospection),
      featureGlyphProtocol = _getBool(.featureGlyphProtocol),
      optimizeMode = .fromValue(_getInt(.optimize)),
      versionString = _getString(.versionString),
      versionMajor = _getInt(.versionMajor),
      versionMinor = _getInt(.versionMinor),
      versionPatch = _getInt(.versionPatch),
      versionPre = _getString(.versionPre),
      versionBuild = _getString(.versionBuild);

  static bool _getBool(BuildInfo data) => bindings.utility.buildInfoBool(data);

  static int _getInt(BuildInfo data) => bindings.utility.buildInfo(data);

  static String _getString(BuildInfo data) {
    return bindings.utility.buildInfoString(data);
  }
}

import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../generated/libghostty_enums.g.dart';

/// One binary-safe representation in an atomic clipboard write.
///
/// The bytes have already been decoded from any protocol encoding and are
/// copied into Dart-owned memory before the callback runs. Empty [data] is an
/// explicit empty representation; it does not request that the clipboard be
/// cleared.
@immutable
final class ClipboardContent {
  /// MIME type of the representation.
  final String mime;

  /// Decoded bytes owned by Dart.
  final Uint8List data;

  const ClipboardContent({required this.mime, required this.data});
}

/// The synchronous answer to a [ClipboardReadRequest].
@immutable
final class ClipboardReadReply {
  /// Whether a successful credentialed request should be remembered.
  final bool remember;

  /// MIME types available on the clipboard when requested.
  final List<String> available;

  /// Outcome of the read.
  final ClipboardReadResult result;

  /// Clipboard representations returned to the terminal program.
  final List<ClipboardContent> contents;

  const ClipboardReadReply({
    required this.result,
    this.remember = false,
    this.contents = const [],
    this.available = const [],
  });
}

/// A synchronous request to read clipboard representations.
@immutable
final class ClipboardReadRequest {
  /// Whether the program requested the complete available MIME list.
  final bool list;

  /// Name of the requesting program, when supplied by the protocol.
  final String name;

  /// Whether the terminal already granted this program permission.
  final bool granted;

  /// Whether this request supplied credentials that can be remembered.
  final bool canRemember;

  /// MIME types requested by the terminal program, in preference order.
  final List<String> mimes;

  /// Clipboard source.
  final ClipboardLocation location;

  const ClipboardReadRequest({
    required this.list,
    required this.name,
    required this.mimes,
    required this.granted,
    required this.location,
    required this.canRemember,
  });
}

/// A protocol-neutral request to replace or clear clipboard contents.
///
/// Every entry in [contents] represents the same logical value and should be
/// committed atomically. Empty [contents] requests that [location] be cleared.
/// OSC 52, iTerm2 OSC 1337, and Kitty OSC 5522 writes use this same normalized
/// representation.
@immutable
final class ClipboardWrite {
  /// Name of the program requesting the write, when supplied by the protocol.
  final String name;

  /// Whether the terminal already granted this program permission.
  final bool granted;

  /// Whether this request supplied credentials that can be remembered.
  final bool canRemember;

  /// Clipboard destination.
  final ClipboardLocation location;

  /// Representations of the value to commit atomically.
  final List<ClipboardContent> contents;

  const ClipboardWrite({
    required this.location,
    required this.contents,
    this.name = '',
    this.granted = false,
    this.canRemember = false,
  });
}

/// An image decoded from PNG into top-to-bottom RGBA pixel bytes.
///
/// Return this from the PNG decoder callback. The binding copies [rgba] into
/// memory owned by libghostty before returning from the callback.
@immutable
final class DecodedImage {
  /// Image width in pixels.
  final int width;

  /// Image height in pixels.
  final int height;

  /// RGBA bytes in row-major order.
  final Uint8List rgba;

  const DecodedImage({
    required this.width,
    required this.height,
    required this.rgba,
  });
}

/// A desktop notification requested by terminal content through OSC 9 or
/// OSC 777.
///
/// Both strings are copied into Dart-owned memory. [title] is empty when the
/// protocol omits it.
@immutable
final class DesktopNotification {
  /// Notification title.
  final String title;

  /// Notification body.
  final String body;

  const DesktopNotification({required this.title, required this.body});

  @override
  int get hashCode => Object.hash(title, body);

  @override
  bool operator ==(Object other) =>
      other is DesktopNotification &&
      other.title == title &&
      other.body == body;
}

/// Primary device attributes (DA1) response data.
///
/// Response format: CSI ? Pp ; Ps... c
/// where Pp is the conformance level and Ps are feature codes.
@immutable
final class DeviceAttributesPrimary {
  /// Conformance level (Pp parameter). For example, 62 for VT220.
  final int conformanceLevel;

  /// DA1 feature codes (Ps parameters).
  final List<int> features;

  const DeviceAttributesPrimary({
    this.conformanceLevel = 62,
    this.features = const [],
  });
}

/// Response data for device attributes queries (DA1/DA2/DA3).
///
/// Return this from a device-attributes callback to respond to CSI c, CSI > c,
/// or CSI = c queries. The terminal reads whichever sub-structure matches the
/// request type.
@immutable
final class DeviceAttributesResponse {
  /// Primary device attributes (DA1). Response to CSI c.
  final DeviceAttributesPrimary primary;

  /// Secondary device attributes (DA2). Response to CSI > c.
  final DeviceAttributesSecondary secondary;

  /// Tertiary device attributes (DA3). Response to CSI = c.
  final DeviceAttributesTertiary tertiary;

  const DeviceAttributesResponse({
    this.primary = const DeviceAttributesPrimary(),
    this.secondary = const DeviceAttributesSecondary(),
    this.tertiary = const DeviceAttributesTertiary(),
  });
}

/// Secondary device attributes (DA2) response data.
///
/// Response format: CSI > Pp ; Pv ; Pc c
@immutable
final class DeviceAttributesSecondary {
  /// Terminal type identifier (Pp). For example, 1 for VT220.
  final int deviceType;

  /// Firmware/patch version number (Pv).
  final int firmwareVersion;

  /// ROM cartridge registration number (Pc). Always 0 for emulators.
  final int romCartridge;

  const DeviceAttributesSecondary({
    this.deviceType = 1,
    this.firmwareVersion = 0,
    this.romCartridge = 0,
  });

  @override
  int get hashCode => Object.hash(deviceType, firmwareVersion, romCartridge);

  @override
  bool operator ==(Object other) =>
      other is DeviceAttributesSecondary &&
      other.deviceType == deviceType &&
      other.firmwareVersion == firmwareVersion &&
      other.romCartridge == romCartridge;
}

/// Tertiary device attributes (DA3) response data.
///
/// Response format: DCS ! | D...D ST (DECRPTUI).
@immutable
final class DeviceAttributesTertiary {
  /// Unit ID encoded as 8 uppercase hex digits in the response.
  final int unitId;

  const DeviceAttributesTertiary({this.unitId = 0});

  @override
  int get hashCode => unitId.hashCode;

  @override
  bool operator ==(Object other) =>
      other is DeviceAttributesTertiary && other.unitId == unitId;
}

/// A progress report requested by terminal content through OSC 9;4.
@immutable
final class TerminalProgress {
  /// Literal state reported by the running program.
  final TerminalProgressState state;

  /// Percentage from 0 through 100, or null when the protocol omits it.
  final int? progress;

  const TerminalProgress({required this.state, this.progress});

  @override
  int get hashCode => Object.hash(state, progress);

  @override
  bool operator ==(Object other) =>
      other is TerminalProgress &&
      other.state == state &&
      other.progress == progress;
}

/// Memory held by a terminal's screens and Kitty graphics storage.
///
/// Resident bytes include compressed page storage but exclude Kitty image
/// bytes. Reading this value visits every screen page, so read it when
/// checking memory budgets instead of after every terminal write.
@immutable
final class TerminalMemoryUsage {
  /// Whether this build can compress scrollback pages.
  final bool compressionSupported;

  /// Number of pages allocated for the primary screen.
  final int primaryPages;

  /// Address space reserved for primary screen pages.
  final int primaryVirtualBytes;

  /// Resident primary screen bytes, including compressed page data.
  final int primaryResidentBytes;

  /// Number of compressed primary screen pages.
  final int primaryCompressedPages;

  /// Compressed primary data bytes, already included in resident bytes.
  final int primaryCompressedBytes;

  /// Kitty image bytes stored for the primary screen.
  final int primaryImageBytes;

  /// Number of pages allocated for the alternate screen.
  final int alternatePages;

  /// Address space reserved for alternate screen pages.
  final int alternateVirtualBytes;

  /// Resident alternate screen bytes, including compressed page data.
  final int alternateResidentBytes;

  /// Number of compressed alternate screen pages.
  final int alternateCompressedPages;

  /// Compressed alternate data bytes, already included in resident bytes.
  final int alternateCompressedBytes;

  /// Kitty image bytes stored for the alternate screen.
  final int alternateImageBytes;

  const TerminalMemoryUsage({
    required this.compressionSupported,
    required this.primaryPages,
    required this.primaryVirtualBytes,
    required this.primaryResidentBytes,
    required this.primaryCompressedPages,
    required this.primaryCompressedBytes,
    required this.primaryImageBytes,
    required this.alternatePages,
    required this.alternateVirtualBytes,
    required this.alternateResidentBytes,
    required this.alternateCompressedPages,
    required this.alternateCompressedBytes,
    required this.alternateImageBytes,
  });

  @override
  int get hashCode => Object.hashAll([
    compressionSupported,
    primaryPages,
    primaryVirtualBytes,
    primaryResidentBytes,
    primaryCompressedPages,
    primaryCompressedBytes,
    primaryImageBytes,
    alternatePages,
    alternateVirtualBytes,
    alternateResidentBytes,
    alternateCompressedPages,
    alternateCompressedBytes,
    alternateImageBytes,
  ]);

  @override
  bool operator ==(Object other) =>
      other is TerminalMemoryUsage &&
      other.compressionSupported == compressionSupported &&
      other.primaryPages == primaryPages &&
      other.primaryVirtualBytes == primaryVirtualBytes &&
      other.primaryResidentBytes == primaryResidentBytes &&
      other.primaryCompressedPages == primaryCompressedPages &&
      other.primaryCompressedBytes == primaryCompressedBytes &&
      other.primaryImageBytes == primaryImageBytes &&
      other.alternatePages == alternatePages &&
      other.alternateVirtualBytes == alternateVirtualBytes &&
      other.alternateResidentBytes == alternateResidentBytes &&
      other.alternateCompressedPages == alternateCompressedPages &&
      other.alternateCompressedBytes == alternateCompressedBytes &&
      other.alternateImageBytes == alternateImageBytes;
}

/// An unsupported terminal string sequence captured by the terminal parser.
///
/// [content] is copied into Dart-owned memory and may contain arbitrary binary
/// data. [truncated] is true when the configured capture limit shortened it.
@immutable
final class TerminalUnknownSequence {
  /// The protocol sequence family.
  final TerminalUnknownSequenceTag tag;

  /// The captured sequence content, excluding its protocol delimiters.
  final Uint8List content;

  /// Whether the byte limit or an allocation failure shortened the content.
  final bool truncated;

  /// How an OSC sequence ended, or null for other sequence families.
  final OscTerminator? terminator;

  const TerminalUnknownSequence({
    required this.tag,
    required this.content,
    required this.truncated,
    this.terminator,
  });
}

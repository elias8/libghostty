import 'dart:convert';

import '../../generated/libghostty_enums.g.dart';
import '../types.dart';

_PackedBit _bit(Map<String, dynamic> value, String name, int totalWidth) {
  final lsb = _requiredNonNegativeInt(value, 'lsb', name);
  final width = _positiveInt(value, 'width');
  if (lsb + width > totalWidth) {
    throw FormatException('Packed cell bit "$name" exceeds its container.');
  }
  return _PackedBit(lsb: lsb, width: width);
}

void _checkKeys(
  Map<String, dynamic> value,
  Set<String> expected,
  String context,
) {
  for (final key in value.keys) {
    if (!expected.contains(key)) {
      throw FormatException(
        'Layout metadata has an unknown $context field: $key.',
      );
    }
  }
  for (final key in expected) {
    if (!value.containsKey(key)) {
      throw FormatException('Layout metadata is missing $context field: $key.');
    }
  }
}

Map<String, dynamic> _decodeLayoutJson(String source) {
  final value = jsonDecode(source);
  if (value is! Map) {
    throw const FormatException('Layout metadata must have an object root.');
  }
  return value.cast<String, dynamic>();
}

Map<String, dynamic> _descriptor(Map<String, dynamic> types, String name) {
  final descriptor = types[name];
  if (descriptor is Map<String, dynamic>) return descriptor;
  throw FormatException('Layout metadata is missing type "$name".');
}

int _extract(int raw, _PackedBit bit) {
  return raw ~/ bit.divisor % bit.modulus;
}

_PackedArm _packedArm(
  Map<String, dynamic> arms,
  String name,
  int width,
  Map<String, String> expectedBits,
) {
  final value = _requiredMap(arms, name);
  if (value['kind'] != 'packed' || value['width'] != width) {
    throw FormatException('Packed cell arm "$name" has an invalid width.');
  }
  final bits = _requiredMap(value, 'bits');
  if (bits.keys.length != expectedBits.length ||
      !expectedBits.keys.every(bits.containsKey)) {
    throw FormatException('Packed cell arm "$name" has invalid fields.');
  }
  final parsed = <String, _PackedBit>{};
  for (final entry in expectedBits.entries) {
    final bit = _requiredMap(bits, entry.key);
    if (bit['kind'] != null || bit['type'] != entry.value) {
      throw FormatException(
        'Packed cell arm "$name" field "${entry.key}" has an invalid type.',
      );
    }
    parsed[entry.key] = _bit(bit, '$name.${entry.key}', width);
  }
  return _PackedArm(width: width, bits: parsed);
}

Map<String, dynamic> _packedDescriptor(
  Map<String, dynamic> types,
  String name,
) {
  final descriptor = types[name];
  if (descriptor is! Map<String, dynamic> || descriptor['kind'] != 'packed') {
    throw FormatException('Layout metadata type "$name" is not packed.');
  }
  return descriptor;
}

int _positiveInt(Map<String, dynamic> value, String key) {
  final result = value[key];
  if (result is int && result > 0) return result;
  throw FormatException(
    'Layout metadata field "$key" must be a positive integer.',
  );
}

int _powerOfTwo(int exponent) {
  var value = 1;
  for (var i = 0; i < exponent; i++) {
    value *= 2;
  }
  return value;
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> value, String key) {
  final result = value[key];
  if (result is Map<String, dynamic>) return result;
  throw FormatException('Layout metadata field "$key" must be an object.');
}

int _requiredNonNegativeInt(
  Map<String, dynamic> value,
  String key,
  String context,
) {
  final result = value[key];
  if (result is int && result >= 0) return result;
  throw FormatException(
    'Layout metadata field "$key" for "$context" must be a '
    'non-negative integer.',
  );
}

String _requiredString(Map<String, dynamic> value, String key) {
  final result = value[key];
  if (result is String && result.isNotEmpty) return result;
  throw FormatException(
    'Layout metadata field "$key" must be a non-empty string.',
  );
}

int _requireStruct(Map<String, dynamic> descriptor, String name) {
  if (descriptor['kind'] != 'struct') {
    throw FormatException('Layout metadata type "$name" is not a struct.');
  }
  return _requiredNonNegativeInt(descriptor, 'size', name);
}

_PackedBit _scalarBit(
  Map<String, dynamic> bits,
  String name,
  String type,
  int totalWidth,
) {
  final value = _requiredMap(bits, name);
  if (value['kind'] != null || value['type'] != type) {
    throw FormatException('Packed cell bit "$name" has an invalid type.');
  }
  return _bit(value, name, totalWidth);
}

_PackedBit _unionBit(
  Map<String, dynamic> bits,
  String name,
  String tag,
  int totalWidth,
) {
  final value = _requiredMap(bits, name);
  if (value['kind'] != 'union' || value['tag'] != tag) {
    throw FormatException('Packed cell union "$name" has an invalid tag.');
  }
  return _bit(value, name, totalWidth);
}

void _validateDisjoint(Iterable<_PackedBit> bits, String context) {
  final ordered = bits.toList()..sort((a, b) => a.lsb.compareTo(b.lsb));
  for (var i = 1; i < ordered.length; i++) {
    if (ordered[i - 1].lsb + ordered[i - 1].width > ordered[i].lsb) {
      throw FormatException('$context contains overlapping bits.');
    }
  }
}

/// Precomputed C struct sizes and field offsets for WASM32.
///
/// Parsed once from [ghostty_type_json] at initialization. All fields
/// are final ints resolved from the JSON, so method calls use direct
/// field access with no map lookups.
final class Layouts {
  final int maxAlignment;
  final PackedCellLayout cellLayout;

  // GhosttyCellsView
  late final int cellsViewSize;
  late final int cellsViewPtr;
  late final int cellsViewLen;

  // GhosttyBuffer
  late final int bufferSize;
  late final int bufferPtr;
  late final int bufferCap;
  late final int bufferLen;

  // GhosttyWriter
  late final int writerSize;
  late final int writerWrite;
  late final int writerUserdata;

  // GhosttyClipboardContent
  late final int clipboardContentSize;
  late final int clipboardContentMime;
  late final int clipboardContentData;

  // GhosttyClipboardWrite
  late final int clipboardWriteSize;
  late final int clipboardWriteLocation;
  late final int clipboardWriteContents;
  late final int clipboardWriteContentsLen;

  // GhosttyTerminalDesktopNotification
  late final int desktopNotificationSize;
  late final int desktopNotificationTitle;
  late final int desktopNotificationBody;

  // GhosttyTerminalProgressReport
  late final int terminalProgressReportSize;
  late final int terminalProgressReportState;
  late final int terminalProgressReportProgress;

  // GhosttyTerminalModeConfig
  late final int terminalModeConfigSize;
  late final int terminalModeConfigMode;
  late final int terminalModeConfigValue;

  // GhosttyColorRgb
  late final int colorRgbSize;
  late final int colorRgbR;
  late final int colorRgbG;
  late final int colorRgbB;

  // GhosttyColorX11Entry
  late final int colorX11EntrySize;
  late final int colorX11EntryName;
  late final int colorX11EntryColor;

  // GhosttyDeviceAttributes
  late final int deviceAttrsFeatures;
  late final int deviceAttrsNumFeatures;
  late final int deviceAttrsDeviceType;
  late final int deviceAttrsFirmwareVersion;
  late final int deviceAttrsRomCartridge;
  late final int deviceAttrsUnitId;

  // GhosttyFormatterTerminalOptions
  late final int formatterOptsSize;
  late final int formatterOptsFormat;
  late final int formatterOptsUnwrap;
  late final int formatterOptsTrim;
  late final int formatterOptsExtra;
  late final int formatterOptsSelection;

  // GhosttyFormatterTerminalExtra
  late final int formatterTermExtraSize;
  late final int formatterTermExtraPalette;
  late final int formatterTermExtraModes;
  late final int formatterTermExtraScrollingRegion;
  late final int formatterTermExtraTabstops;
  late final int formatterTermExtraPwd;
  late final int formatterTermExtraKeyboard;
  late final int formatterTermExtraScreen;

  // GhosttyFormatterScreenExtra
  late final int formatterScreenExtraSize;
  late final int formatterScreenExtraCursor;
  late final int formatterScreenExtraStyle;
  late final int formatterScreenExtraHyperlink;
  late final int formatterScreenExtraProtection;
  late final int formatterScreenExtraKittyKeyboard;
  late final int formatterScreenExtraCharsets;

  // GhosttySelection
  late final int selectionSize;
  late final int selectionStart;
  late final int selectionEnd;
  late final int selectionRectangle;

  // GhosttyTerminalSelectWordOptions
  late final int selectWordSize;
  late final int selectWordRef;
  late final int selectWordBoundaryCodepoints;
  late final int selectWordBoundaryCodepointsLen;

  // GhosttyTerminalSelectWordBetweenOptions
  late final int selectWordBetweenSize;
  late final int selectWordBetweenStart;
  late final int selectWordBetweenEnd;
  late final int selectWordBetweenBoundaryCodepoints;
  late final int selectWordBetweenBoundaryCodepointsLen;

  // GhosttyTerminalSelectLineOptions
  late final int selectLineSize;
  late final int selectLineRef;
  late final int selectLineWhitespace;
  late final int selectLineWhitespaceLen;
  late final int selectLineSemanticPromptBoundary;

  // GhosttyTerminalSelectionFormatOptions
  late final int selectionFormatSize;
  late final int selectionFormatEmit;
  late final int selectionFormatUnwrap;
  late final int selectionFormatTrim;
  late final int selectionFormatSelection;

  // GhosttyGridRef
  late final int gridRefSize;
  late final int gridRefNode;
  late final int gridRefX;
  late final int gridRefY;

  // GhosttyKittyGraphicsPlacementRenderInfo
  late final int kittyRenderInfoSize;
  late final int kittyRenderInfoPixelWidth;
  late final int kittyRenderInfoPixelHeight;
  late final int kittyRenderInfoGridCols;
  late final int kittyRenderInfoGridRows;
  late final int kittyRenderInfoViewportCol;
  late final int kittyRenderInfoViewportRow;
  late final int kittyRenderInfoViewportVisible;
  late final int kittyRenderInfoSourceX;
  late final int kittyRenderInfoSourceY;
  late final int kittyRenderInfoSourceWidth;
  late final int kittyRenderInfoSourceHeight;

  // GhosttyKittyGraphicsUnicodePlacementRenderInfo
  late final int kittyUnicodeRenderInfoSize;
  late final int kittyUnicodeRenderInfoViewportCol;
  late final int kittyUnicodeRenderInfoViewportRow;
  late final int kittyUnicodeRenderInfoZ;
  late final int kittyUnicodeRenderInfoCellOffsetX;
  late final int kittyUnicodeRenderInfoCellOffsetY;
  late final int kittyUnicodeRenderInfoPixelWidth;
  late final int kittyUnicodeRenderInfoPixelHeight;
  late final int kittyUnicodeRenderInfoSourceX;
  late final int kittyUnicodeRenderInfoSourceY;
  late final int kittyUnicodeRenderInfoSourceWidth;
  late final int kittyUnicodeRenderInfoSourceHeight;

  // GhosttyPointCoordinate
  late final int pointCoordinateSize;
  late final int pointCoordinateX;
  late final int pointCoordinateY;

  // GhosttyCodepoints
  late final int codepointsSize;
  late final int codepointsPtr;
  late final int codepointsLen;

  // GhosttySurfacePosition
  late final int surfacePositionSize;
  late final int surfacePositionX;
  late final int surfacePositionY;

  // GhosttySelectionGestureBehaviors
  late final int gestureBehaviorsSize;
  late final int gestureBehaviorsSingleClick;
  late final int gestureBehaviorsDoubleClick;
  late final int gestureBehaviorsTripleClick;

  // GhosttySelectionGestureGeometry
  late final int gestureGeometrySize;
  late final int gestureGeometryColumns;
  late final int gestureGeometryCellWidth;
  late final int gestureGeometryPaddingLeft;
  late final int gestureGeometryScreenHeight;

  // GhosttyMouseEncoderSize
  late final int mouseEncoderSizeSize;
  late final int mouseEncoderSizeScreenWidth;
  late final int mouseEncoderSizeScreenHeight;
  late final int mouseEncoderSizeCellWidth;
  late final int mouseEncoderSizeCellHeight;
  late final int mouseEncoderSizePaddingTop;
  late final int mouseEncoderSizePaddingBottom;
  late final int mouseEncoderSizePaddingRight;
  late final int mouseEncoderSizePaddingLeft;

  // GhosttyMousePosition
  late final int mousePosSize;
  late final int mousePosY;

  // GhosttyPoint
  late final int pointSize;
  late final int pointX;
  late final int pointY;

  // GhosttyRenderStateColors
  late final int colorsSize;
  late final int colorsBg;
  late final int colorsFg;
  late final int colorsCursor;
  late final int colorsCursorHasValue;
  late final int colorsPalette;

  // GhosttyRenderStateCursor
  late final int cursorSize;
  late final int cursorViewportHasValue;
  late final int cursorViewportX;
  late final int cursorViewportY;
  late final int cursorWideTail;
  late final int cursorVisible;
  late final int cursorBlinking;
  late final int cursorPasswordInput;
  late final int cursorVisualStyle;

  // GhosttyRenderStateRowSelection
  late final int renderRowSelectionSize;
  late final int renderRowSelectionStartX;
  late final int renderRowSelectionEndX;

  // GhosttySizeReportSize
  late final int sizeReportSize;
  late final int sizeReportColumns;
  late final int sizeReportCellWidth;
  late final int sizeReportCellHeight;

  // GhosttyString
  late final int stringSize;
  late final int stringLen;

  // GhosttyStyle
  late final int styleSize;
  late final int styleFg;
  late final int styleBg;
  late final int styleUnderlineColor;
  late final int styleBold;
  late final int styleItalic;
  late final int styleFaint;
  late final int styleBlink;
  late final int styleInverse;
  late final int styleInvisible;
  late final int styleStrikethrough;
  late final int styleOverline;
  late final int styleUnderline;

  // GhosttyStyleColor
  late final int styleColorR;
  late final int styleColorG;
  late final int styleColorB;

  // GhosttyTerminalScrollbar
  late final int scrollbarSize;
  late final int scrollbarOffset;
  late final int scrollbarVisible;

  // GhosttyTerminalScrollViewport
  late final int scrollViewportSize;
  late final int scrollViewportDelta;

  // GhosttySysImage
  late final int sysImageSize;
  late final int sysImageWidth;
  late final int sysImageHeight;
  late final int sysImageData;
  late final int sysImageDataLen;

  // GhosttySgrAttribute
  late final int sgrAttributeSize;

  // GhosttyTerminalUnknownSequence
  late final int unknownSequenceSize;
  late final int unknownSequenceTag;
  late final int unknownSequenceValue;

  // GhosttyTerminalUnknownStringSequence
  late final int unknownStringSequenceSize;
  late final int unknownStringSequenceTruncated;
  late final int unknownStringSequenceContent;

  factory Layouts.fromJson(String source) {
    final root = _decodeLayoutJson(source);
    _checkKeys(root, const {
      'schema',
      'abi',
      'library_version',
      'commit',
      'dirty',
      'types',
    }, 'manifest');
    final schema = root['schema'];
    if (schema != 1) {
      throw FormatException('Unsupported layout metadata schema: $schema.');
    }

    final abi = _requiredMap(root, 'abi');
    _checkKeys(abi, const {
      'target',
      'os',
      'environment',
      'pointer_size',
      'usize_size',
      'max_alignment',
      'endian',
    }, 'abi');
    if (abi['target'] != 'wasm32') {
      throw FormatException(
        'Unsupported layout metadata target: ${abi['target']}.',
      );
    }
    if (abi['pointer_size'] != 4 || abi['usize_size'] != 4) {
      throw const FormatException(
        'Wasm layout metadata must use 32-bit pointers and usize.',
      );
    }
    if (abi['endian'] != 'little') {
      throw FormatException(
        'Unsupported Wasm layout metadata endianness: ${abi['endian']}.',
      );
    }
    final maxAlignment = _positiveInt(abi, 'max_alignment');
    _requiredString(root, 'library_version');
    final commit = root['commit'];
    if (commit != null && commit is! String) {
      throw const FormatException(
        'Layout metadata field "commit" must be a string or null.',
      );
    }
    final dirty = root['dirty'];
    if (dirty != null && dirty is! bool) {
      throw const FormatException(
        'Layout metadata field "dirty" must be a boolean or null.',
      );
    }
    final types = _requiredMap(root, 'types');
    final cellLayout = PackedCellLayout.fromTypes(types);
    return Layouts._(types, maxAlignment, cellLayout);
  }

  Layouts._(Map<String, dynamic> types, this.maxAlignment, this.cellLayout) {
    var struct = _Struct(types, 'GhosttyCellsView');
    cellsViewSize = struct.size;
    cellsViewPtr = struct['ptr'];
    cellsViewLen = struct['len'];

    struct = _Struct(types, 'GhosttyBuffer');
    bufferSize = struct.size;
    bufferPtr = struct['ptr'];
    bufferCap = struct['cap'];
    bufferLen = struct['len'];

    struct = _Struct(types, 'GhosttyWriter');
    writerSize = struct.size;
    writerWrite = struct['write'];
    writerUserdata = struct['userdata'];

    struct = _Struct(types, 'GhosttyClipboardContent');
    clipboardContentSize = struct.size;
    clipboardContentMime = struct['mime'];
    clipboardContentData = struct['data'];

    struct = _Struct(types, 'GhosttyClipboardWrite');
    clipboardWriteSize = struct.size;
    clipboardWriteLocation = struct['location'];
    clipboardWriteContents = struct['contents'];
    clipboardWriteContentsLen = struct['contents_len'];

    struct = _Struct(types, 'GhosttyTerminalDesktopNotification');
    desktopNotificationSize = struct.size;
    desktopNotificationTitle = struct['title'];
    desktopNotificationBody = struct['body'];

    struct = _Struct(types, 'GhosttyTerminalProgressReport');
    terminalProgressReportSize = struct.size;
    terminalProgressReportState = struct['state'];
    terminalProgressReportProgress = struct['progress'];

    struct = _Struct(types, 'GhosttyTerminalModeConfig');
    terminalModeConfigSize = struct.size;
    terminalModeConfigMode = struct['mode'];
    terminalModeConfigValue = struct['value'];

    struct = _Struct(types, 'GhosttyColorRgb');
    colorRgbSize = struct.size;
    colorRgbR = struct['r'];
    colorRgbG = struct['g'];
    colorRgbB = struct['b'];

    struct = _Struct(types, 'GhosttyColorX11Entry');
    colorX11EntrySize = struct.size;
    colorX11EntryName = struct['name'];
    colorX11EntryColor = struct['color'];

    struct = _Struct(types, 'GhosttyDeviceAttributes');
    final primaryOff = struct['primary'];
    final secondaryOff = struct['secondary'];
    final tertiaryOff = struct['tertiary'];
    var sub = _Struct(types, 'GhosttyDeviceAttributesPrimary');
    deviceAttrsFeatures = primaryOff + sub['features'];
    deviceAttrsNumFeatures = primaryOff + sub['num_features'];
    sub = _Struct(types, 'GhosttyDeviceAttributesSecondary');
    deviceAttrsDeviceType = secondaryOff + sub['device_type'];
    deviceAttrsFirmwareVersion = secondaryOff + sub['firmware_version'];
    deviceAttrsRomCartridge = secondaryOff + sub['rom_cartridge'];
    sub = _Struct(types, 'GhosttyDeviceAttributesTertiary');
    deviceAttrsUnitId = tertiaryOff + sub['unit_id'];

    struct = _Struct(types, 'GhosttyFormatterTerminalOptions');
    formatterOptsSize = struct.size;
    formatterOptsFormat = struct['emit'];
    formatterOptsUnwrap = struct['unwrap'];
    formatterOptsTrim = struct['trim'];
    formatterOptsExtra = struct['extra'];
    formatterOptsSelection = struct['selection'];

    struct = _Struct(types, 'GhosttyFormatterTerminalExtra');
    formatterTermExtraSize = struct.size;
    formatterTermExtraPalette = struct['palette'];
    formatterTermExtraModes = struct['modes'];
    formatterTermExtraScrollingRegion = struct['scrolling_region'];
    formatterTermExtraTabstops = struct['tabstops'];
    formatterTermExtraPwd = struct['pwd'];
    formatterTermExtraKeyboard = struct['keyboard'];
    formatterTermExtraScreen = struct['screen'];

    struct = _Struct(types, 'GhosttyFormatterScreenExtra');
    formatterScreenExtraSize = struct.size;
    formatterScreenExtraCursor = struct['cursor'];
    formatterScreenExtraStyle = struct['style'];
    formatterScreenExtraHyperlink = struct['hyperlink'];
    formatterScreenExtraProtection = struct['protection'];
    formatterScreenExtraKittyKeyboard = struct['kitty_keyboard'];
    formatterScreenExtraCharsets = struct['charsets'];

    struct = _Struct(types, 'GhosttySelection');
    selectionSize = struct.size;
    selectionStart = struct['start'];
    selectionEnd = struct['end'];
    selectionRectangle = struct['rectangle'];

    struct = _Struct(types, 'GhosttyTerminalSelectWordOptions');
    selectWordSize = struct.size;
    selectWordRef = struct['ref'];
    selectWordBoundaryCodepoints = struct['boundary_codepoints'];
    selectWordBoundaryCodepointsLen = struct['boundary_codepoints_len'];

    struct = _Struct(types, 'GhosttyTerminalSelectWordBetweenOptions');
    selectWordBetweenSize = struct.size;
    selectWordBetweenStart = struct['start'];
    selectWordBetweenEnd = struct['end'];
    selectWordBetweenBoundaryCodepoints = struct['boundary_codepoints'];
    selectWordBetweenBoundaryCodepointsLen = struct['boundary_codepoints_len'];

    struct = _Struct(types, 'GhosttyTerminalSelectLineOptions');
    selectLineSize = struct.size;
    selectLineRef = struct['ref'];
    selectLineWhitespace = struct['whitespace'];
    selectLineWhitespaceLen = struct['whitespace_len'];
    selectLineSemanticPromptBoundary = struct['semantic_prompt_boundary'];

    struct = _Struct(types, 'GhosttyTerminalSelectionFormatOptions');
    selectionFormatSize = struct.size;
    selectionFormatEmit = struct['emit'];
    selectionFormatUnwrap = struct['unwrap'];
    selectionFormatTrim = struct['trim'];
    selectionFormatSelection = struct['selection'];

    struct = _Struct(types, 'GhosttyGridRef');
    gridRefSize = struct.size;
    gridRefNode = struct['node'];
    gridRefX = struct['x'];
    gridRefY = struct['y'];

    struct = _Struct(types, 'GhosttyKittyGraphicsPlacementRenderInfo');
    kittyRenderInfoSize = struct.size;
    kittyRenderInfoPixelWidth = struct['pixel_width'];
    kittyRenderInfoPixelHeight = struct['pixel_height'];
    kittyRenderInfoGridCols = struct['grid_cols'];
    kittyRenderInfoGridRows = struct['grid_rows'];
    kittyRenderInfoViewportCol = struct['viewport_col'];
    kittyRenderInfoViewportRow = struct['viewport_row'];
    kittyRenderInfoViewportVisible = struct['viewport_visible'];
    kittyRenderInfoSourceX = struct['source_x'];
    kittyRenderInfoSourceY = struct['source_y'];
    kittyRenderInfoSourceWidth = struct['source_width'];
    kittyRenderInfoSourceHeight = struct['source_height'];

    struct = _Struct(types, 'GhosttyKittyGraphicsUnicodePlacementRenderInfo');
    kittyUnicodeRenderInfoSize = struct.size;
    kittyUnicodeRenderInfoViewportCol = struct['viewport_col'];
    kittyUnicodeRenderInfoViewportRow = struct['viewport_row'];
    kittyUnicodeRenderInfoZ = struct['z'];
    kittyUnicodeRenderInfoCellOffsetX = struct['cell_offset_x'];
    kittyUnicodeRenderInfoCellOffsetY = struct['cell_offset_y'];
    kittyUnicodeRenderInfoPixelWidth = struct['pixel_width'];
    kittyUnicodeRenderInfoPixelHeight = struct['pixel_height'];
    kittyUnicodeRenderInfoSourceX = struct['source_x'];
    kittyUnicodeRenderInfoSourceY = struct['source_y'];
    kittyUnicodeRenderInfoSourceWidth = struct['source_width'];
    kittyUnicodeRenderInfoSourceHeight = struct['source_height'];

    struct = _Struct(types, 'GhosttyMouseEncoderSize');
    mouseEncoderSizeSize = struct.size;
    mouseEncoderSizeScreenWidth = struct['screen_width'];
    mouseEncoderSizeScreenHeight = struct['screen_height'];
    mouseEncoderSizeCellWidth = struct['cell_width'];
    mouseEncoderSizeCellHeight = struct['cell_height'];
    mouseEncoderSizePaddingTop = struct['padding_top'];
    mouseEncoderSizePaddingBottom = struct['padding_bottom'];
    mouseEncoderSizePaddingRight = struct['padding_right'];
    mouseEncoderSizePaddingLeft = struct['padding_left'];

    struct = _Struct(types, 'GhosttyMousePosition');
    mousePosSize = struct.size;
    mousePosY = struct['y'];

    struct = _Struct(types, 'GhosttyPoint');
    pointSize = struct.size;
    final valueOff = struct['value'];
    sub = _Struct(types, 'GhosttyPointCoordinate');
    pointX = valueOff + sub['x'];
    pointY = valueOff + sub['y'];
    pointCoordinateSize = sub.size;
    pointCoordinateX = sub['x'];
    pointCoordinateY = sub['y'];

    struct = _Struct(types, 'GhosttyCodepoints');
    codepointsSize = struct.size;
    codepointsPtr = struct['ptr'];
    codepointsLen = struct['len'];

    struct = _Struct(types, 'GhosttySurfacePosition');
    surfacePositionSize = struct.size;
    surfacePositionX = struct['x'];
    surfacePositionY = struct['y'];

    struct = _Struct(types, 'GhosttySelectionGestureBehaviors');
    gestureBehaviorsSize = struct.size;
    gestureBehaviorsSingleClick = struct['single_click'];
    gestureBehaviorsDoubleClick = struct['double_click'];
    gestureBehaviorsTripleClick = struct['triple_click'];

    struct = _Struct(types, 'GhosttySelectionGestureGeometry');
    gestureGeometrySize = struct.size;
    gestureGeometryColumns = struct['columns'];
    gestureGeometryCellWidth = struct['cell_width'];
    gestureGeometryPaddingLeft = struct['padding_left'];
    gestureGeometryScreenHeight = struct['screen_height'];

    struct = _Struct(types, 'GhosttyRenderStateColors');
    colorsSize = struct.size;
    colorsBg = struct['background'];
    colorsFg = struct['foreground'];
    colorsCursor = struct['cursor'];
    colorsCursorHasValue = struct['cursor_has_value'];
    colorsPalette = struct['palette'];

    struct = _Struct(types, 'GhosttyRenderStateCursor');
    cursorSize = struct.size;
    cursorViewportHasValue = struct['viewport_has_value'];
    cursorViewportX = struct['viewport_x'];
    cursorViewportY = struct['viewport_y'];
    cursorWideTail = struct['wide_tail'];
    cursorVisible = struct['visible'];
    cursorBlinking = struct['blinking'];
    cursorPasswordInput = struct['password_input'];
    cursorVisualStyle = struct['visual_style'];

    struct = _Struct(types, 'GhosttyRenderStateRowSelection');
    renderRowSelectionSize = struct.size;
    renderRowSelectionStartX = struct['start_x'];
    renderRowSelectionEndX = struct['end_x'];

    struct = _Struct(types, 'GhosttySizeReportSize');
    sizeReportSize = struct.size;
    sizeReportColumns = struct['columns'];
    sizeReportCellWidth = struct['cell_width'];
    sizeReportCellHeight = struct['cell_height'];

    struct = _Struct(types, 'GhosttyString');
    stringSize = struct.size;
    stringLen = struct['len'];

    struct = _Struct(types, 'GhosttyStyle');
    styleSize = struct.size;
    styleFg = struct['fg_color'];
    styleBg = struct['bg_color'];
    styleUnderlineColor = struct['underline_color'];
    styleBold = struct['bold'];
    styleItalic = struct['italic'];
    styleFaint = struct['faint'];
    styleBlink = struct['blink'];
    styleInverse = struct['inverse'];
    styleInvisible = struct['invisible'];
    styleStrikethrough = struct['strikethrough'];
    styleOverline = struct['overline'];
    styleUnderline = struct['underline'];

    struct = _Struct(types, 'GhosttyStyleColor');
    final scValueOff = struct['value'];
    sub = _Struct(types, 'GhosttyColorRgb');
    styleColorR = scValueOff + sub['r'];
    styleColorG = scValueOff + sub['g'];
    styleColorB = scValueOff + sub['b'];

    struct = _Struct(types, 'GhosttyTerminalScrollbar');
    scrollbarSize = struct.size;
    scrollbarOffset = struct['offset'];
    scrollbarVisible = struct['len'];

    struct = _Struct(types, 'GhosttyTerminalScrollViewport');
    scrollViewportSize = struct.size;
    scrollViewportDelta = struct['value'];

    struct = _Struct(types, 'GhosttySysImage');
    sysImageSize = struct.size;
    sysImageWidth = struct['width'];
    sysImageHeight = struct['height'];
    sysImageData = struct['data'];
    sysImageDataLen = struct['data_len'];

    struct = _Struct(types, 'GhosttySgrAttribute');
    sgrAttributeSize = struct.size;

    struct = _Struct(types, 'GhosttyTerminalUnknownSequence');
    unknownSequenceSize = struct.size;
    unknownSequenceTag = struct['tag'];
    unknownSequenceValue = struct['value'];

    struct = _Struct(types, 'GhosttyTerminalUnknownStringSequence');
    unknownStringSequenceSize = struct.size;
    unknownStringSequenceTruncated = struct['truncated'];
    unknownStringSequenceContent = struct['content'];
  }
}

/// Packed cell metadata decoded from the artifact's ABI manifest.
///
/// This is an internal Wasm implementation detail. Bit positions are always
/// read from [ghostty_type_json] and are never part of the Dart API.
final class PackedCellLayout {
  final int size;
  final String underlying;
  final _PackedBit _contentTag;
  final _PackedBit _contentRgbR;
  final _PackedBit _contentRgbG;
  final _PackedBit _contentRgbB;
  final _PackedBit _styleId;
  final _PackedBit _wide;
  final _PackedBit _protected;
  final _PackedBit _hyperlink;
  final _PackedBit _semanticContent;
  final _PackedBit _codepoint;
  final _PackedBit _codepointGrapheme;

  factory PackedCellLayout.fromTypes(Map<String, dynamic> types) {
    final descriptor = _packedDescriptor(types, 'GhosttyCell');
    final cellSize = _positiveInt(descriptor, 'size');
    final underlying = _requiredString(descriptor, 'underlying');
    if (underlying != 'u64' || cellSize != 8) {
      throw const FormatException(
        'GhosttyCell must use an 8-byte u64 packed representation.',
      );
    }
    final bits = _requiredMap(descriptor, 'bits');
    const fieldNames = {
      'content_tag',
      'content',
      'style_id',
      'wide',
      'protected',
      'hyperlink',
      'semantic_content',
    };
    if (bits.keys.length != fieldNames.length ||
        !fieldNames.every(bits.containsKey)) {
      throw const FormatException(
        'GhosttyCell packed fields do not match the supported ABI.',
      );
    }
    final contentTag = _scalarBit(
      bits,
      'content_tag',
      'GhosttyCellContentTag',
      cellSize * 8,
    );
    final content = _unionBit(bits, 'content', 'content_tag', cellSize * 8);
    final styleId = _scalarBit(
      bits,
      'style_id',
      'GhosttyStyleId',
      cellSize * 8,
    );
    final wide = _scalarBit(bits, 'wide', 'GhosttyCellWide', cellSize * 8);
    final protected = _scalarBit(bits, 'protected', 'bool', cellSize * 8);
    final hyperlink = _scalarBit(bits, 'hyperlink', 'bool', cellSize * 8);
    final semanticContent = _scalarBit(
      bits,
      'semantic_content',
      'GhosttyCellSemanticContent',
      cellSize * 8,
    );
    _validateDisjoint([
      contentTag,
      content,
      styleId,
      wide,
      protected,
      hyperlink,
      semanticContent,
    ], 'GhosttyCell');

    final contentValue = _requiredMap(bits, 'content');
    final arms = _requiredMap(contentValue, 'arms');
    const armNames = {
      'CODEPOINT',
      'CODEPOINT_GRAPHEME',
      'BG_COLOR_PALETTE',
      'BG_COLOR_RGB',
    };
    if (!armNames.containsAll(arms.keys) ||
        arms.keys.length != armNames.length) {
      throw const FormatException(
        'GhosttyCell content arms do not match the supported ABI.',
      );
    }
    final codepoint = _packedArm(arms, 'CODEPOINT', content.width, {
      'codepoint': 'u21',
    });
    final codepointGrapheme = _packedArm(
      arms,
      'CODEPOINT_GRAPHEME',
      content.width,
      {'codepoint': 'u21'},
    );
    final palette = _packedArm(arms, 'BG_COLOR_PALETTE', content.width, {
      'index': 'GhosttyColorPaletteIndex',
    });
    final rgb = _packedArm(arms, 'BG_COLOR_RGB', content.width, {
      'r': 'u8',
      'g': 'u8',
      'b': 'u8',
    });
    for (final arm in [codepoint, codepointGrapheme, palette, rgb]) {
      _validateDisjoint(arm.bits.values, 'GhosttyCell content arm');
    }

    return PackedCellLayout._(
      size: cellSize,
      underlying: underlying,
      contentTag: contentTag,
      contentRgbR: _nestedBit(content, rgb, 'r'),
      contentRgbG: _nestedBit(content, rgb, 'g'),
      contentRgbB: _nestedBit(content, rgb, 'b'),
      styleId: styleId,
      wide: wide,
      protected: protected,
      hyperlink: hyperlink,
      semanticContent: semanticContent,
      codepoint: _nestedBit(content, codepoint, 'codepoint'),
      codepointGrapheme: _nestedBit(content, codepointGrapheme, 'codepoint'),
    );
  }

  PackedCellLayout._({
    required this.size,
    required this.underlying,
    required _PackedBit contentTag,
    required _PackedBit contentRgbR,
    required _PackedBit contentRgbG,
    required _PackedBit contentRgbB,
    required _PackedBit styleId,
    required _PackedBit wide,
    required _PackedBit protected,
    required _PackedBit hyperlink,
    required _PackedBit semanticContent,
    required _PackedBit codepoint,
    required _PackedBit codepointGrapheme,
  }) : _contentTag = contentTag,
       _contentRgbR = contentRgbR,
       _contentRgbG = contentRgbG,
       _contentRgbB = contentRgbB,
       _styleId = styleId,
       _wide = wide,
       _protected = protected,
       _hyperlink = hyperlink,
       _semanticContent = semanticContent,
       _codepoint = codepoint,
       _codepointGrapheme = codepointGrapheme;

  /// Decodes one manifest-described cell into reusable storage.
  ///
  /// [target] is overwritten and returned. The packed value is borrowed from
  /// the row view and remains valid only until the render state is updated.
  RawCellData decodeInto(int raw, RawCellData target) {
    final contentTag = CellContentTag.fromValue(_extract(raw, _contentTag));
    final hasGrapheme = contentTag == .codepointGrapheme;
    final codepoint = switch (contentTag) {
      .codepoint => _extract(raw, _codepoint),
      .codepointGrapheme => _extract(raw, _codepointGrapheme),
      .bgColorPalette || .bgColorRgb => 0,
    };
    target.set(
      rawCell: raw,
      contentTag: contentTag,
      codepoint: codepoint,
      hasGrapheme: hasGrapheme,
      styleId: _extract(raw, _styleId),
      wide: CellWide.fromValue(_extract(raw, _wide)),
      isProtected: _extract(raw, _protected) != 0,
      hasHyperlink: _extract(raw, _hyperlink) != 0,
      semanticContent: .fromValue(_extract(raw, _semanticContent)),
      hasBackgroundRgb: contentTag == .bgColorRgb,
      backgroundR: _extract(raw, _contentRgbR),
      backgroundG: _extract(raw, _contentRgbG),
      backgroundB: _extract(raw, _contentRgbB),
    );
    return target;
  }

  static _PackedBit _nestedBit(_PackedBit parent, _PackedArm arm, String name) {
    final bit = arm.bits[name];
    if (bit == null) throw StateError('Missing packed cell arm bit: $name.');
    return _PackedBit(lsb: parent.lsb + bit.lsb, width: bit.width);
  }
}

final class _PackedArm {
  final int width;
  final Map<String, _PackedBit> bits;

  const _PackedArm({required this.width, required this.bits});
}

final class _PackedBit {
  final int lsb;
  final int width;
  final int divisor;
  final int modulus;

  _PackedBit({required this.lsb, required this.width})
    : divisor = _powerOfTwo(lsb),
      modulus = _powerOfTwo(width);
}

/// Typed accessor for a single struct's layout from the JSON.
final class _Struct {
  final int size;
  final Map<String, dynamic> _fields;

  _Struct(Map<String, dynamic> types, String name)
    : this._fromDescriptor(_descriptor(types, name), name);

  _Struct._fromDescriptor(Map<String, dynamic> descriptor, String name)
    : size = _requireStruct(descriptor, name),
      _fields = _requiredMap(descriptor, 'fields');

  int operator [](String field) =>
      _requiredNonNegativeInt(_requiredMap(_fields, field), 'offset', field);
}

// Flutter's public KeyEvent omits native layout metadata that terminal
// protocols need. Desktop plugins send a companion record before Flutter's
// own key messages; the deprecated raw event is used only to correlate that
// record with the KeyEvent object delivered to Focus.
// ignore_for_file: deprecated_member_use

import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:libghostty/libghostty.dart' show Mods;

final class NativeKeyboardMetadata {
  final Mods mods;
  final Mods consumedMods;
  final int unshiftedCodepoint;
  final String? textWithoutAlt;
  final bool deadKey;

  const NativeKeyboardMetadata({
    required this.mods,
    required this.consumedMods,
    required this.unshiftedCodepoint,
    required this.textWithoutAlt,
    required this.deadKey,
  });
}

final class NativeKeyboardMetadataStore {
  static final instance = NativeKeyboardMetadataStore._();
  static const _channelName = 'dev.flterm/native_keyboard';
  static const _queueLimit = 64;

  final _nativeEvents = ListQueue<_NativeKeyboardRecord>();
  final _pairedEvents = ListQueue<_PairedKeyboardRecord>();
  final _metadata = Expando<NativeKeyboardMetadata>();
  var _initialized = false;

  NativeKeyboardMetadataStore._();

  void ensureInitialized() {
    if (_initialized || kIsWeb || !_isDesktopPlatform) return;
    _initialized = true;
    const BasicMessageChannel<Object?>(
      _channelName,
      StandardMessageCodec(),
    ).setMessageHandler(_handleMessage);
    RawKeyboard.instance.addListener(_handleRawEvent);
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  NativeKeyboardMetadata? forEvent(KeyEvent event) => _metadata[event];

  bool get _isDesktopPlatform => switch (defaultTargetPlatform) {
    .linux || .macOS || .windows => true,
    .android || .fuchsia || .iOS => false,
  };

  bool _handleKeyEvent(KeyEvent event) {
    if (event.synthesized) return false;
    final down = event is! KeyUpEvent;
    final records = _pairedEvents.toList();
    final index = records.lastIndexWhere(
      (record) =>
          record.down == down && record.physicalKey == event.physicalKey,
    );
    if (index < 0) return false;
    final record = records[index];
    _pairedEvents.removeWhere(
      (candidate) =>
          candidate.down == down && candidate.physicalKey == event.physicalKey,
    );
    _metadata[event] = record.metadata;
    return false;
  }

  Future<Object?> _handleMessage(Object? message) async {
    final record = _NativeKeyboardRecord.fromMessage(message);
    if (record == null) return null;
    if (record.eventTime != 0 && _nativeEvents.any(record.sameNativeEvent)) {
      return null;
    }
    _nativeEvents.addLast(record);
    while (_nativeEvents.length > _queueLimit) {
      _nativeEvents.removeFirst();
    }
    return null;
  }

  void _handleRawEvent(RawKeyEvent event) {
    final down = event is RawKeyDownEvent;
    final records = _nativeEvents.toList();
    final index = records.lastIndexWhere(
      (record) => record.down == down && record.matches(event.data),
    );
    if (index < 0) return;
    final record = records[index];
    _nativeEvents.removeWhere(
      (candidate) => candidate.down == down && candidate.matches(event.data),
    );
    _pairedEvents.addLast(
      _PairedKeyboardRecord(
        physicalKey: event.physicalKey,
        down: down,
        metadata: record.metadata,
      ),
    );
    while (_pairedEvents.length > _queueLimit) {
      _pairedEvents.removeFirst();
    }
  }
}

final class _NativeKeyboardRecord {
  final String platform;
  final int scanCode;
  final int keyCode;
  final bool down;
  final int eventTime;
  final NativeKeyboardMetadata metadata;

  const _NativeKeyboardRecord({
    required this.platform,
    required this.scanCode,
    required this.keyCode,
    required this.down,
    required this.eventTime,
    required this.metadata,
  });

  static _NativeKeyboardRecord? fromMessage(Object? message) {
    if (message is! Map<Object?, Object?>) return null;
    final platform = message['platform'];
    final scanCode = message['scanCode'];
    final keyCode = message['keyCode'];
    final down = message['down'];
    final eventTime = message['eventTime'];
    final mods = message['mods'];
    final consumedMods = message['consumedMods'];
    final unshiftedCodepoint = message['unshiftedCodepoint'];
    final textWithoutAlt = message['textWithoutAlt'];
    final deadKey = message['deadKey'];
    if (platform is! String ||
        !const {'linux', 'macos', 'windows'}.contains(platform) ||
        scanCode is! int ||
        scanCode < 0 ||
        keyCode is! int ||
        keyCode < 0 ||
        down is! bool ||
        eventTime is! int ||
        eventTime < 0 ||
        mods is! int ||
        consumedMods is! int ||
        unshiftedCodepoint is! int ||
        unshiftedCodepoint < 0 ||
        unshiftedCodepoint > 0x10FFFF ||
        (unshiftedCodepoint >= 0xD800 && unshiftedCodepoint <= 0xDFFF) ||
        (textWithoutAlt != null && textWithoutAlt is! String) ||
        deadKey is! bool) {
      return null;
    }
    return _NativeKeyboardRecord(
      platform: platform,
      scanCode: scanCode,
      keyCode: keyCode,
      down: down,
      eventTime: eventTime,
      metadata: NativeKeyboardMetadata(
        mods: _modsFromBits(mods),
        consumedMods: _modsFromBits(consumedMods),
        unshiftedCodepoint: unshiftedCodepoint,
        textWithoutAlt: textWithoutAlt as String?,
        deadKey: deadKey,
      ),
    );
  }

  bool matches(RawKeyEventData data) {
    return switch ((platform, data)) {
      ('linux', final RawKeyEventDataLinux event) =>
        event.scanCode == scanCode && event.keyCode == keyCode,
      ('macos', final RawKeyEventDataMacOs event) => event.keyCode == keyCode,
      ('windows', final RawKeyEventDataWindows event) =>
        event.scanCode == scanCode && event.keyCode == keyCode,
      _ => false,
    };
  }

  bool sameNativeEvent(_NativeKeyboardRecord other) {
    return platform == other.platform &&
        scanCode == other.scanCode &&
        keyCode == other.keyCode &&
        down == other.down &&
        eventTime == other.eventTime;
  }
}

final class _PairedKeyboardRecord {
  final PhysicalKeyboardKey physicalKey;
  final bool down;
  final NativeKeyboardMetadata metadata;

  const _PairedKeyboardRecord({
    required this.physicalKey,
    required this.down,
    required this.metadata,
  });
}

Mods _modsFromBits(int bits) {
  var mods = const Mods.none();
  if (bits & (1 << 0) != 0) mods = mods | const Mods.shift();
  if (bits & (1 << 1) != 0) mods = mods | const Mods.ctrl();
  if (bits & (1 << 2) != 0) mods = mods | const Mods.alt();
  if (bits & (1 << 3) != 0) mods = mods | const Mods.superKey();
  if (bits & (1 << 4) != 0) mods = mods | const Mods.capsLock();
  if (bits & (1 << 5) != 0) mods = mods | const Mods.numLock();
  if (bits & (1 << 6) != 0) mods = mods | const Mods.shiftSide();
  if (bits & (1 << 7) != 0) mods = mods | const Mods.ctrlSide();
  if (bits & (1 << 8) != 0) mods = mods | const Mods.altSide();
  if (bits & (1 << 9) != 0) mods = mods | const Mods.superSide();
  return mods;
}

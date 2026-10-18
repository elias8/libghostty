part of 'terminal.dart';

VoidCallback _weakBell(WeakReference<_TerminalCallbacks> reference) =>
    () => reference.target?._bell?.call();

ClipboardReadCallback _weakClipboardRead(
  WeakReference<_TerminalCallbacks> reference,
) => (request) {
  final callback = reference.target?._clipboardRead;
  return callback == null
      ? const ClipboardReadReply(result: .denied)
      : callback(request);
};

ClipboardWriteCallback _weakClipboardWrite(
  WeakReference<_TerminalCallbacks> reference,
) => (request) {
  final callback = reference.target?._clipboardWrite;
  return callback == null ? ClipboardWriteResult.denied : callback(request);
};

ValueGetter<ColorScheme?> _weakColorScheme(
  WeakReference<_TerminalCallbacks> reference,
) =>
    () => reference.target?._colorScheme?.call();

DesktopNotificationCallback _weakDesktopNotification(
  WeakReference<_TerminalCallbacks> reference,
) =>
    (notification) =>
        reference.target?._desktopNotification?.call(notification);

ValueGetter<DeviceAttributesResponse?> _weakDeviceAttributes(
  WeakReference<_TerminalCallbacks> reference,
) =>
    () => reference.target?._deviceAttributes?.call();

ValueGetter<Uint8List> _weakEnquiry(
  WeakReference<_TerminalCallbacks> reference,
) => () {
  final callback = reference.target?._enquiry;
  return callback == null ? Uint8List(0) : callback();
};

TerminalProgramStatusCallback _weakProgramStatus(
  WeakReference<_TerminalCallbacks> reference,
) =>
    (status) => reference.target?._programStatus?.call(status);

TerminalProgressCallback _weakProgressReport(
  WeakReference<_TerminalCallbacks> reference,
) =>
    (progress) => reference.target?._progressReport?.call(progress);

VoidCallback _weakPwdChanged(WeakReference<_TerminalCallbacks> reference) =>
    () => reference.target?._pwdChanged?.call();

ValueSetter<bool> _weakRenderHold(
  WeakReference<_TerminalCallbacks> reference,
) =>
    (hold) => reference.target?._renderHold?.call(hold);

VoidCallback _weakReset(WeakReference<_TerminalCallbacks> reference) =>
    () => reference.target?._reset?.call();

TerminalSemanticPromptCallback _weakSemanticPrompt(
  WeakReference<_TerminalCallbacks> reference,
) =>
    (prompt) => reference.target?._semanticPrompt?.call(prompt);

ValueGetter<TerminalSizeInfo?> _weakSize(
  WeakReference<_TerminalCallbacks> reference,
) =>
    () => reference.target?._size?.call();

VoidCallback _weakTitleChanged(WeakReference<_TerminalCallbacks> reference) =>
    () => reference.target?._titleChanged?.call();

TerminalUnknownSequenceCallback _weakUnknownSequence(
  WeakReference<_TerminalCallbacks> reference,
) =>
    (sequence) => reference.target?._unknownSequence?.call(sequence);

ValueSetter<Uint8List> _weakWritePty(
  WeakReference<_TerminalCallbacks> reference,
) =>
    (bytes) => reference.target?._writePty?.call(bytes);

ValueGetter<String> _weakXtversion(
  WeakReference<_TerminalCallbacks> reference,
) => () {
  final callback = reference.target?._xtversion;
  return callback == null ? '' : callback();
};

final class _TerminalCallbacks {
  VoidCallback? _bell;
  ClipboardReadCallback? _clipboardRead;
  ClipboardWriteCallback? _clipboardWrite;
  ValueGetter<ColorScheme?>? _colorScheme;
  DesktopNotificationCallback? _desktopNotification;
  ValueGetter<DeviceAttributesResponse?>? _deviceAttributes;
  ValueGetter<Uint8List>? _enquiry;
  TerminalProgramStatusCallback? _programStatus;
  TerminalProgressCallback? _progressReport;
  VoidCallback? _pwdChanged;
  ValueSetter<bool>? _renderHold;
  VoidCallback? _reset;
  TerminalSemanticPromptCallback? _semanticPrompt;
  ValueGetter<TerminalSizeInfo?>? _size;
  VoidCallback? _titleChanged;
  TerminalUnknownSequenceCallback? _unknownSequence;
  ValueSetter<Uint8List>? _writePty;
  ValueGetter<String>? _xtversion;

  late final _reference = WeakReference(this);
  late final _bellTrampoline = _weakBell(_reference);
  late final _colorSchemeTrampoline = _weakColorScheme(_reference);
  late final _clipboardReadTrampoline = _weakClipboardRead(_reference);
  late final _clipboardWriteTrampoline = _weakClipboardWrite(_reference);
  late final _deviceAttributesTrampoline = _weakDeviceAttributes(_reference);
  late final _enquiryTrampoline = _weakEnquiry(_reference);
  late final _programStatusTrampoline = _weakProgramStatus(_reference);
  late final _progressReportTrampoline = _weakProgressReport(_reference);
  late final _pwdChangedTrampoline = _weakPwdChanged(_reference);
  late final _renderHoldTrampoline = _weakRenderHold(_reference);
  late final _resetTrampoline = _weakReset(_reference);
  late final _semanticPromptTrampoline = _weakSemanticPrompt(_reference);
  late final _sizeTrampoline = _weakSize(_reference);
  late final _titleChangedTrampoline = _weakTitleChanged(_reference);
  late final _unknownSequenceTrampoline = _weakUnknownSequence(_reference);
  late final _writePtyTrampoline = _weakWritePty(_reference);
  late final _xtversionTrampoline = _weakXtversion(_reference);
  late final _desktopNotificationTrampoline = _weakDesktopNotification(
    _reference,
  );

  void clear() {
    _bell = null;
    _clipboardRead = null;
    _clipboardWrite = null;
    _colorScheme = null;
    _desktopNotification = null;
    _deviceAttributes = null;
    _enquiry = null;
    _programStatus = null;
    _progressReport = null;
    _pwdChanged = null;
    _renderHold = null;
    _reset = null;
    _semanticPrompt = null;
    _size = null;
    _titleChanged = null;
    _unknownSequence = null;
    _writePty = null;
    _xtversion = null;
  }

  void setBell(LibGhosttyHandle handle, VoidCallback? callback) {
    bindings.terminal.terminalSetOnBell(
      handle,
      callback == null ? null : _bellTrampoline,
    );
    _bell = callback;
  }

  void setClipboardRead(
    LibGhosttyHandle handle,
    ClipboardReadCallback? callback,
  ) {
    bindings.terminal.terminalSetOnClipboardRead(
      handle,
      callback == null ? null : _clipboardReadTrampoline,
    );
    _clipboardRead = callback;
  }

  void setClipboardWrite(
    LibGhosttyHandle handle,
    ClipboardWriteCallback? callback,
  ) {
    bindings.terminal.terminalSetOnClipboardWrite(
      handle,
      callback == null ? null : _clipboardWriteTrampoline,
    );
    _clipboardWrite = callback;
  }

  void setColorScheme(
    LibGhosttyHandle handle,
    ValueGetter<ColorScheme?>? callback,
  ) {
    bindings.terminal.terminalSetOnColorScheme(
      handle,
      callback == null ? null : _colorSchemeTrampoline,
    );
    _colorScheme = callback;
  }

  void setDesktopNotification(
    LibGhosttyHandle handle,
    DesktopNotificationCallback? callback,
  ) {
    bindings.terminal.terminalSetOnDesktopNotification(
      handle,
      callback == null ? null : _desktopNotificationTrampoline,
    );
    _desktopNotification = callback;
  }

  void setDeviceAttributes(
    LibGhosttyHandle handle,
    ValueGetter<DeviceAttributesResponse?>? callback,
  ) {
    bindings.terminal.terminalSetOnDeviceAttributes(
      handle,
      callback == null ? null : _deviceAttributesTrampoline,
    );
    _deviceAttributes = callback;
  }

  void setEnquiry(LibGhosttyHandle handle, ValueGetter<Uint8List>? callback) {
    bindings.terminal.terminalSetOnEnquiry(
      handle,
      callback == null ? null : _enquiryTrampoline,
    );
    _enquiry = callback;
  }

  void setProgramStatus(
    LibGhosttyHandle handle,
    TerminalProgramStatusCallback? callback,
  ) {
    bindings.terminal.terminalSetOnProgramStatus(
      handle,
      callback == null ? null : _programStatusTrampoline,
    );
    _programStatus = callback;
  }

  void setProgressReport(
    LibGhosttyHandle handle,
    TerminalProgressCallback? callback,
  ) {
    bindings.terminal.terminalSetOnProgressReport(
      handle,
      callback == null ? null : _progressReportTrampoline,
    );
    _progressReport = callback;
  }

  void setPwdChanged(LibGhosttyHandle handle, VoidCallback? callback) {
    bindings.terminal.terminalSetOnPwdChanged(
      handle,
      callback == null ? null : _pwdChangedTrampoline,
    );
    _pwdChanged = callback;
  }

  void setRenderHold(LibGhosttyHandle handle, ValueSetter<bool>? callback) {
    bindings.terminal.terminalSetOnRenderHold(
      handle,
      callback == null ? null : _renderHoldTrampoline,
    );
    _renderHold = callback;
  }

  void setReset(LibGhosttyHandle handle, VoidCallback? callback) {
    bindings.terminal.terminalSetOnReset(
      handle,
      callback == null ? null : _resetTrampoline,
    );
    _reset = callback;
  }

  void setSemanticPrompt(
    LibGhosttyHandle handle,
    TerminalSemanticPromptCallback? callback,
  ) {
    bindings.terminal.terminalSetOnSemanticPrompt(
      handle,
      callback == null ? null : _semanticPromptTrampoline,
    );
    _semanticPrompt = callback;
  }

  void setSize(
    LibGhosttyHandle handle,
    ValueGetter<TerminalSizeInfo?>? callback,
  ) {
    bindings.terminal.terminalSetOnSize(
      handle,
      callback == null ? null : _sizeTrampoline,
    );
    _size = callback;
  }

  void setTitleChanged(LibGhosttyHandle handle, VoidCallback? callback) {
    bindings.terminal.terminalSetOnTitleChanged(
      handle,
      callback == null ? null : _titleChangedTrampoline,
    );
    _titleChanged = callback;
  }

  void setUnknownSequence(
    LibGhosttyHandle handle,
    TerminalUnknownSequenceCallback? callback,
  ) {
    bindings.terminal.terminalSetOnUnknownSequence(
      handle,
      callback == null ? null : _unknownSequenceTrampoline,
    );
    _unknownSequence = callback;
  }

  void setWritePty(LibGhosttyHandle handle, ValueSetter<Uint8List>? callback) {
    bindings.terminal.terminalSetOnWritePty(
      handle,
      callback == null ? null : _writePtyTrampoline,
    );
    _writePty = callback;
  }

  void setXtversion(LibGhosttyHandle handle, ValueGetter<String>? callback) {
    bindings.terminal.terminalSetOnXtversion(
      handle,
      callback == null ? null : _xtversionTrampoline,
    );
    _xtversion = callback;
  }
}

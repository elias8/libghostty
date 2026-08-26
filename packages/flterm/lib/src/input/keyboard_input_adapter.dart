import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:libghostty/libghostty.dart' hide KeyEvent;

import '../controller/terminal_controller.dart';
import '../foundation.dart';
import 'input_message.dart';
import 'keyboard_event_normalizer.dart';
import 'text_input_session.dart';

/// Coordinates hardware-key and platform text-input handling for a
/// [TerminalView].
///
/// The adapter owns the focus binding and [TextInputSession], combines physical
/// and virtual modifiers, routes raw key events, and publishes visible IME
/// preedit text. Terminal protocol encoding remains controller-owned.
///
/// Attachment is view-bound: replacing the focus node or Flutter view ID
/// detaches the platform text-input connection before rebinding it. Raw keys
/// and text deltas converge on controller methods, so neither path writes
/// directly to libghostty or invokes public output callbacks.
@internal
final class KeyboardInputAdapter extends ChangeNotifier {
  static const _space = 0x20;
  static const _delete = 0x7f;
  static const _macFunctionKeyStart = 0xF700;
  static const _macFunctionKeyEnd = 0xF8FF;

  final TerminalControllerImpl _controller;
  final _textInput = TextInputSession();
  final KeyboardEventNormalizer _normalizer;
  final TerminalKeyEventNormalizer? _keyEventNormalizer;
  final _textInputPhysicalKeys = <PhysicalKeyboardKey>{};
  FocusNode? _focusNode;
  Brightness _keyboardAppearance = .dark;
  var _preeditText = '';
  var _wasFocused = false;

  KeyboardInputAdapter(this._controller, {this._keyEventNormalizer})
    : _normalizer = KeyboardEventNormalizer() {
    _textInput
      ..onTextCommitted = _controller.handleTextCommitted
      ..onDelete = _controller.handleTextDeleted
      ..onNewline = _controller.handleTextNewline
      ..onPreeditChanged = _handlePreeditChanged;
  }

  set keyboardAppearance(Brightness value) {
    if (_keyboardAppearance == value) return;
    _keyboardAppearance = value;
    _textInput.keyboardAppearance = value;
  }

  String get preeditText => _preeditText;

  Mods get _currentMods {
    var mods = _controller.virtualMods;
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isShiftPressed) mods |= const Mods.shift();
    if (keyboard.isControlPressed) mods |= const Mods.ctrl();
    if (keyboard.isAltPressed) mods |= const Mods.alt();
    if (keyboard.isMetaPressed) mods |= const Mods.superKey();
    final pressed = keyboard.physicalKeysPressed;
    if (pressed.contains(PhysicalKeyboardKey.shiftRight)) {
      mods |= const Mods.shiftSide();
    }
    if (pressed.contains(PhysicalKeyboardKey.controlRight)) {
      mods |= const Mods.ctrlSide();
    }
    if (pressed.contains(PhysicalKeyboardKey.altRight)) {
      mods |= const Mods.altSide();
    }
    if (pressed.contains(PhysicalKeyboardKey.metaRight)) {
      mods |= const Mods.superSide();
    }
    final lockModes = keyboard.lockModesEnabled;
    if (lockModes.contains(KeyboardLockMode.capsLock)) {
      mods |= const Mods.capsLock();
    }
    if (lockModes.contains(KeyboardLockMode.numLock)) {
      mods |= const Mods.numLock();
    }
    return mods;
  }

  bool get _isDesktopPlatform {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      .linux || .macOS || .windows => true,
      .android || .fuchsia || .iOS => false,
    };
  }

  void attach(FocusNode focusNode, {required int viewId}) {
    final previousFocusNode = _focusNode;
    final wasFocused = _wasFocused;
    previousFocusNode?.removeListener(_handleFocusChanged);
    if (previousFocusNode != null && !identical(previousFocusNode, focusNode)) {
      _textInput.detach();
    }
    _focusNode = focusNode;
    _wasFocused = focusNode.hasFocus;
    focusNode.addListener(_handleFocusChanged);
    _textInput
      ..viewId = viewId
      ..keyboardAppearance = _keyboardAppearance;
    if (_wasFocused) {
      if (!wasFocused) _controller.handleFocusChanged(focused: true);
      _textInput.ensureAttached(keyboardAppearance: _keyboardAppearance);
    }
  }

  void detach() {
    if (_wasFocused && !_controller.isDisposed) {
      _controller.handleFocusChanged(focused: false);
    }
    _focusNode?.removeListener(_handleFocusChanged);
    _focusNode = null;
    _wasFocused = false;
    _preeditText = '';
    _textInput.detach();
  }

  @override
  void dispose() {
    detach();
    super.dispose();
  }

  KeyEventResult handleKeyEvent(KeyEvent event) {
    final action = switch (event) {
      KeyDownEvent() => KeyAction.press,
      KeyUpEvent() => KeyAction.release,
      KeyRepeatEvent() => KeyAction.repeat,
      _ => null,
    };
    if (action == null) return .ignored;

    final key = keyFromPhysical(event.physicalKey);
    final mods = _currentMods;
    final character = _encoderCharacter(event.character);
    final composing =
        _textInput.hasActiveComposition || _preeditText.isNotEmpty;
    var normalized = _normalizer.normalize(
      event,
      key: key,
      action: action,
      mods: mods,
      character: character,
      composing: composing,
      optionAsAlt: _controller.config.optionAsAlt,
    );
    normalized = _keyEventNormalizer?.call(event, normalized) ?? normalized;

    if (action == .release &&
        _textInputPhysicalKeys.remove(event.physicalKey)) {
      return .skipRemainingHandlers;
    }
    if (normalized.deferToTextInput) {
      if (action == .press || action == .repeat) {
        _textInputPhysicalKeys.add(event.physicalKey);
      }
      return .skipRemainingHandlers;
    }
    if (action == .press) _textInputPhysicalKeys.remove(event.physicalKey);

    final virtualMods = _controller.virtualMods;
    final consumedMods =
        normalized.consumedMods ^ (normalized.consumedMods & virtualMods);
    final terminalMods = consumedMods.hasCtrl
        ? normalized.mods ^ const Mods.ctrl()
        : normalized.mods;
    final input = KeyInput(
      key: normalized.key,
      action: normalized.action,
      mods: terminalMods,
      character: normalized.text,
      composing: normalized.composing,
      consumedMods: consumedMods,
      unshiftedCodepoint: normalized.unshiftedCodepoint,
    );

    if (_shouldForwardCompositionKey(input)) return .skipRemainingHandlers;

    final disposition = _controller.handleTerminalKey(
      input,
      routeToTextInput: _shouldRouteToTextInput(input),
      forwardDeletionToTextInput: _shouldForwardDeletion(input),
    );
    return switch (disposition) {
      .ignored => .ignored,
      .handled => .handled,
      .skipRemainingHandlers => .skipRemainingHandlers,
    };
  }

  void requestFocus() => _focusNode?.requestFocus();

  void showKeyboard() {
    _focusNode?.requestFocus();
    if (_focusNode?.hasFocus ?? false) _textInput.show();
  }

  void updateTextInputGeometry({
    required Size editableSize,
    required Matrix4 transform,
    required Rect caretRect,
    required Rect composingRect,
  }) {
    _textInput.updateGeometry(
      editableSize: editableSize,
      transform: transform,
      caretRect: caretRect,
      composingRect: composingRect,
    );
  }

  void _handleFocusChanged() {
    final focused = _focusNode?.hasFocus ?? false;
    if (focused == _wasFocused) return;
    _wasFocused = focused;
    _controller.handleFocusChanged(focused: focused);
    if (focused) {
      _textInput.ensureAttached(keyboardAppearance: _keyboardAppearance);
    } else {
      _textInput.hide();
    }
  }

  void _handlePreeditChanged(String value) {
    if (_preeditText == value) return;
    _preeditText = value;
    _controller.handleTextCompositionChanged(active: value.isNotEmpty);
    notifyListeners();
  }

  bool _shouldForwardCompositionKey(KeyInput input) {
    return input.composing &&
        _textInput.isAttached &&
        _isDesktopPlatform &&
        !_shouldRouteToTextInput(input);
  }

  bool _shouldForwardDeletion(KeyInput input) {
    if (!_isDesktopPlatform || !_controller.virtualMods.isEmpty) return false;
    if (input.action != .press && input.action != .repeat) return false;
    if (input.key != .backspace && input.key != .delete) return false;
    final mods = input.mods;
    if (mods.hasShift || mods.hasCtrl || mods.hasAlt || mods.hasSuper) {
      return false;
    }
    return _textInput.consumeCommittedCompositionEdit();
  }

  bool _shouldRouteToTextInput(KeyInput input) {
    if (input.character == null || input.composing) return false;
    if (!_textInput.isAttached || !_isDesktopPlatform) return false;
    if (input.action != .press && input.action != .repeat) return false;
    if (!_controller.virtualMods.isEmpty) return false;
    final mods = input.mods;
    final consumedMods = input.consumedMods;
    return !(mods.hasCtrl && !consumedMods.hasCtrl) &&
        !(mods.hasAlt && !consumedMods.hasAlt) &&
        !mods.hasSuper;
  }

  static String? _encoderCharacter(String? character) {
    if (character == null || character.isEmpty) return null;
    final code = character.codeUnitAt(0);
    if (code < _space || code == _delete) return null;
    if (code >= _macFunctionKeyStart && code <= _macFunctionKeyEnd) return null;
    return character;
  }
}

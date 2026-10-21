import 'package:libghostty/libghostty.dart';

import '../foundation/key_codepoints.dart';
import '../foundation/surface_geometry.dart';
import 'input_message.dart';

/// Owns the reusable terminal resources that encode normalized input.
///
/// It translates renderer-neutral key and pointer values into terminal bytes
/// without owning Flutter focus, gesture, or text-input lifecycle. Reusing the
/// native events and encoders avoids allocations on input hot paths. Each input
/// kind acquires its resources on first use.
final class InputEncoder {
  final Terminal _terminal;
  KeyEvent? _keyEvent;
  MouseEvent? _mouseEvent;
  KeyEncoder? _keyEncoder;
  MouseEncoder? _mouseEncoder;
  SurfaceGeometry? _geometry;
  var _disposed = false;

  InputEncoder(this._terminal);

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _keyEvent?.dispose();
    _mouseEvent?.dispose();
    _keyEncoder?.dispose();
    _mouseEncoder?.dispose();
    _keyEvent = null;
    _mouseEvent = null;
    _keyEncoder = null;
    _mouseEncoder = null;
    _geometry = null;
  }

  String encodeKey(KeyInput input) {
    _checkNotDisposed();
    final event = _keyEvent ??= KeyEvent();
    event
      ..key = input.key
      ..mods = input.mods
      ..action = input.action
      ..utf8 = input.character
      ..composing = input.composing
      ..consumedMods = input.consumedMods
      ..unshiftedCodepoint = input.unshiftedCodepoint;
    return _encodeKeyEvent(event);
  }

  String encodeKeyPress(Key key, {required Mods mods}) {
    _checkNotDisposed();
    final codepoint = unshiftedCodepointForKey(key);
    final event = _keyEvent ??= KeyEvent();
    event
      ..key = key
      ..mods = mods
      ..action = .press
      ..consumedMods = const .none()
      ..unshiftedCodepoint = codepoint
      ..utf8 = codepoint > 0 ? String.fromCharCode(codepoint) : null
      ..composing = false;
    return _encodeKeyEvent(event);
  }

  String encodeMouse(MouseInput input, {required SurfaceGeometry? geometry}) {
    _checkNotDisposed();
    final event = _mouseEvent ??= MouseEvent();
    event
      ..action = input.action
      ..mods = input.mods;
    _setMousePosition(event, input.pixelX, input.pixelY, geometry);
    if (input.button case final button?) {
      event.button = button;
    } else {
      event.clearButton();
    }
    final encoder = _ensureMouseEncoder();
    encoder.sync(_terminal);
    encoder.setAnyButtonPressed(pressed: input.anyButtonPressed);
    return encoder.encode(event);
  }

  String encodeScrollButton(
    ScrollInput input, {
    required MouseButton button,
    required SurfaceGeometry? geometry,
  }) {
    _checkNotDisposed();
    var x = input.pixelX;
    var y = input.pixelY;
    if (geometry != null) {
      final width = geometry.cols * geometry.cellWidth;
      final height = geometry.rows * geometry.cellHeight;
      final edge = 1 / geometry.devicePixelRatio;
      x = x.clamp(0.0, width > edge ? width - edge : 0.0);
      y = y.clamp(0.0, height > edge ? height - edge : 0.0);
    }
    final event = _mouseEvent ??= MouseEvent();
    event
      ..action = .press
      ..button = button
      ..mods = input.mods;
    _setMousePosition(event, x, y, geometry);
    final encoder = _ensureMouseEncoder();
    encoder.sync(_terminal);
    encoder.setAnyButtonPressed(pressed: false);
    return encoder.encode(event);
  }

  void updateGeometry(SurfaceGeometry geometry) {
    _checkNotDisposed();
    _geometry = geometry;
    if (_mouseEncoder case final encoder?) _setMouseSize(encoder, geometry);
  }

  static void _setMouseSize(MouseEncoder encoder, SurfaceGeometry geometry) {
    encoder.setSize(
      MouseEncoderSize(
        screenWidth: geometry.screenWidth,
        screenHeight: geometry.screenHeight,
        cellWidth: geometry.cellWidthPx,
        cellHeight: geometry.cellHeightPx,
        paddingLeft: geometry.paddingLeftPx,
        paddingRight: geometry.paddingRightPx,
        paddingTop: geometry.paddingTopPx,
        paddingBottom: geometry.paddingBottomPx,
      ),
    );
  }

  String _encodeKeyEvent(KeyEvent event) {
    final encoder = _keyEncoder ??= KeyEncoder();
    encoder.sync(_terminal);
    return encoder.encode(event);
  }

  MouseEncoder _ensureMouseEncoder() {
    if (_mouseEncoder case final encoder?) return encoder;
    final encoder = MouseEncoder();
    try {
      if (_geometry case final geometry?) _setMouseSize(encoder, geometry);
    } catch (_) {
      encoder.dispose();
      rethrow;
    }
    _mouseEncoder = encoder;
    return encoder;
  }

  static void _setMousePosition(
    MouseEvent event,
    double x,
    double y,
    SurfaceGeometry? geometry,
  ) {
    if (geometry == null) {
      event.setPosition(x: x, y: y);
      return;
    }
    event.setPosition(
      x: x * geometry.devicePixelRatio + geometry.paddingLeftPx,
      y: y * geometry.devicePixelRatio + geometry.paddingTopPx,
    );
  }

  void _checkNotDisposed() {
    if (_disposed) throw StateError('InputEncoder has been disposed');
  }
}

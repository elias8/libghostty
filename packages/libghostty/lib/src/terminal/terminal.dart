import 'dart:async';
import 'dart:typed_data';

import '../bindings/bindings.dart';
import '../color.dart';
import '../exceptions.dart' show DisposedException;
import 'cursor.dart';
import 'modes.dart';
import 'screen.dart';
import 'scrollback.dart';

/// Terminal emulator state model.
///
/// ```dart
/// final terminal = Terminal(cols: 80, rows: 24);
/// terminal.write(ptyOutput);
///
/// final screen = terminal.screen;
/// for (var row = 0; row < screen.rows; row++) {
///   for (var col = 0; col < screen.cols; col++) {
///     final cell = screen.cellAt(row, col);
///   }
/// }
///
/// terminal.onTitleChanged.listen((title) => setWindowTitle(title));
/// terminal.dispose();
/// ```
class Terminal {
  // ANSI / DEC private mode numbers used by terminalGetMode.
  static const _modeBracketedPaste = 2004;
  static const _modeCursorKeys = 1;
  static const _modeKeypadApplication = 66;
  static const _modeAutoWrap = 7;
  static const _modeOrigin = 6;
  static const _modeInsert = 4;

  static final _ris = Uint8List.fromList('\x1bc'.codeUnits);

  static final _finalizer = Finalizer<int>(
    (handle) => bindings.terminalFree(handle),
  );

  final int _handle;
  var _disposed = false;

  late final NativeScreen _screen;
  late final NativeScrollback _scrollback;

  final _onBell = StreamController<void>.broadcast(sync: true);
  final _onCursorChanged = StreamController<Cursor>.broadcast(sync: true);
  final _onScreenChanged = StreamController<void>.broadcast(sync: true);
  final _onTitleChanged = StreamController<String>.broadcast(sync: true);

  var _lastCursor = const Cursor();
  var _hasContentChanges = false;

  Terminal({
    required int cols,
    required int rows,
    RgbColor? foreground,
    RgbColor? background,
    int scrollbackLimit = 10000,
  }) : _handle = bindings.terminalNewWithConfig(
         cols,
         rows,
         RawTerminalConfig(
           scrollbackLimit: scrollbackLimit * cols * 16,
           fgR: foreground?.r ?? 0,
           fgG: foreground?.g ?? 0,
           fgB: foreground?.b ?? 0,
           fgSet: foreground != null,
           bgR: background?.r ?? 0,
           bgG: background?.g ?? 0,
           bgB: background?.b ?? 0,
           bgSet: background != null,
         ),
       ) {
    _finalizer.attach(this, _handle, detach: this);
    bindings.terminalWrite(_handle, _ris);

    final defaultFg = foreground ?? const RgbColor(0, 0, 0);
    final defaultBg = background ?? const RgbColor(0, 0, 0);
    _screen = NativeScreen(_handle, defaultFg: defaultFg, defaultBg: defaultBg);
    _scrollback = NativeScrollback(
      _handle,
      defaultFg: defaultFg,
      defaultBg: defaultBg,
    );
    _syncRenderState();
    _lastCursor = _readCursor();
  }

  /// Current cursor state.
  Cursor get cursor {
    _ensureNotDisposed();
    return _lastCursor;
  }

  /// Whether cell content has changed since the last [clearContentChanges].
  bool get hasContentChanges {
    _ensureNotDisposed();
    return _hasContentChanges;
  }

  /// Current terminal mode flags.
  TerminalModes get modes {
    _ensureNotDisposed();

    bool mode(int id, {required bool isAnsi}) {
      return bindings.terminalGetMode(_handle, id, isAnsi: isAnsi);
    }

    return TerminalModes(
      alternateScreen: bindings.terminalIsAlternateScreen(_handle),
      bracketedPaste: mode(_modeBracketedPaste, isAnsi: false),
      cursorKeyApplication: mode(_modeCursorKeys, isAnsi: true),
      keypadApplication: mode(_modeKeypadApplication, isAnsi: true),
      autoWrap: mode(_modeAutoWrap, isAnsi: true),
      originMode: mode(_modeOrigin, isAnsi: true),
      insertMode: mode(_modeInsert, isAnsi: false),
    );
  }

  /// Fires when BEL (0x07) is received.
  Stream<void> get onBell => _onBell.stream;

  /// Fires when cursor position or visibility changes.
  Stream<Cursor> get onCursorChanged => _onCursorChanged.stream;

  /// Fires when screen content changes.
  Stream<void> get onScreenChanged => _onScreenChanged.stream;

  /// Fires when the terminal title changes via OSC 0/2.
  Stream<String> get onTitleChanged => _onTitleChanged.stream;

  /// The current visible screen (live view).
  Screen get screen {
    _ensureNotDisposed();
    return _screen;
  }

  /// Scrollback history for the primary screen.
  Scrollback get scrollback {
    _ensureNotDisposed();
    return _scrollback;
  }

  void clearContentChanges() {
    _ensureNotDisposed();
    _hasContentChanges = false;
    bindings.renderStateMarkClean(_handle);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _finalizer.detach(this);
    bindings.terminalFree(_handle);
    unawaited(_onBell.close());
    unawaited(_onCursorChanged.close());
    unawaited(_onScreenChanged.close());
    unawaited(_onTitleChanged.close());
  }

  /// Resize the terminal dimensions.
  void resize({required int cols, required int rows}) {
    _ensureNotDisposed();
    bindings.terminalResize(_handle, cols, rows);
    _syncRenderState();
    _screen.invalidate();
    _pollEvents();
    _onScreenChanged.add(null);
  }

  /// Feed raw bytes from the PTY through the terminal parser.
  void write(Uint8List data) {
    _ensureNotDisposed();
    bindings.terminalWrite(_handle, data);
    _syncRenderState();
    _screen.invalidate();
    _pollEvents();
    _onScreenChanged.add(null);
  }

  void _ensureNotDisposed() {
    if (_disposed) throw const DisposedException('Terminal');
  }

  void _pollEvents() {
    final bells = bindings.terminalGetBellCount(_handle);
    if (bells > 0) {
      for (var i = 0; i < bells; i++) {
        _onBell.add(null);
      }
      bindings.terminalResetBellCount(_handle);
    }
    if (bindings.terminalHasTitleChanged(_handle)) {
      final title = bindings.terminalGetTitle(_handle);
      if (title != null) _onTitleChanged.add(title);
    }
    final newCursor = _readCursor();
    if (newCursor != _lastCursor) {
      _lastCursor = newCursor;
      _onCursorChanged.add(newCursor);
    }
  }

  Cursor _readCursor() {
    const shapeMap = {
      0: CursorShape.block,
      1: CursorShape.bar,
      2: CursorShape.underline,
      3: CursorShape.blockHollow,
    };
    return Cursor(
      col: bindings.renderStateGetCursorX(_handle),
      row: bindings.renderStateGetCursorY(_handle),
      visible: bindings.renderStateGetCursorVisible(_handle),
      shape:
          shapeMap[bindings.renderStateGetCursorStyle(_handle)] ??
          CursorShape.block,
    );
  }

  void _syncRenderState() {
    final dirtyCount = bindings.renderStateUpdate(_handle);
    _hasContentChanges = _hasContentChanges || dirtyCount > 0;
  }
}

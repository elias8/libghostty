part of 'terminal.dart';

/// Formats terminal content as plain text, VT sequences, or HTML.
///
/// Captures a reference to a [Terminal] and reads its current state on each
/// [format] call. The [Terminal] must outlive this formatter.
/// Calling [dispose] more than once is safe; [format] throws [StateError]
/// after either this formatter or its terminal is disposed.
///
/// ```dart
/// final formatter = Formatter(
///   terminal: terminal,
///   format: FormatterFormat.plain,
/// );
/// final text = formatter.format();
/// formatter.dispose();
/// ```
final class Formatter {
  static final _finalizer = Finalizer(bindings.formatter.formatterFree);

  final LibGhosttyHandle _handle;
  Terminal? _terminal;
  final _FormatterSelection? _selection;

  /// Creates a formatter for [terminal].
  ///
  /// [format] selects the output syntax (plain, vt, or html). [extra]
  /// controls which additional terminal state is included in
  /// [FormatterFormat.vt] output (cursor position, modes, palette, etc.);
  /// it has no effect on plain text or HTML output. [selection] restricts
  /// the output to the given range; when null, the entire active screen
  /// is formatted. The selection must be a valid snapshot for the terminal
  /// when passed in. Its endpoints are tracked through terminal changes.
  /// Formatting throws [StateError] if the original screen is not active or
  /// either tracked endpoint has been discarded.
  ///
  /// Throws [OutOfMemoryException] when the allocation fails.
  factory Formatter({
    required Terminal terminal,
    required FormatterFormat format,
    bool unwrap = false,
    bool trim = false,
    FormatterExtra extra = const FormatterExtra(),
    Selection? selection,
  }) {
    final tracked = selection == null
        ? null
        : _FormatterSelection.create(terminal, selection);
    try {
      final handle = bindings.formatter.formatterTerminalNew(
        terminal._requireHandle(),
        format,
        unwrap: unwrap,
        trim: trim,
        extra: extra,
      );
      return Formatter._(terminal, handle, tracked);
    } on Object {
      tracked?.dispose();
      rethrow;
    }
  }

  Formatter._(this._terminal, this._handle, this._selection) {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// Releases the native formatter handle.
  void dispose() {
    final terminal = _terminal;
    if (terminal == null) return;
    bindings.formatter.formatterFree(_handle);
    _finalizer.detach(this);
    _selection?.dispose();
    _terminal = null;
  }

  /// Formats the terminal's current active screen content and returns the
  /// result as a string.
  ///
  /// Each call reads the terminal's current state, so calling [format]
  /// after a [Terminal.write] reflects the updated content.
  ///
  /// Throws [OutOfMemoryException] if the output buffer allocation fails.
  String format() {
    final handle = _requireHandle();
    final selection = _selection;
    if (selection == null) return bindings.formatter.formatterFormat(handle);
    final raw = selection.snapshot(_terminal!);
    bindings.formatter.formatterSetSelection(handle, raw);
    try {
      return bindings.formatter.formatterFormat(handle);
    } finally {
      bindings.formatter.formatterSetSelection(handle, null);
    }
  }

  LibGhosttyHandle _requireHandle() {
    final terminal = _terminal;
    if (terminal == null) throw StateError('Formatter has been disposed');
    if (terminal._disposed) {
      throw StateError('Formatter terminal is disposed');
    }
    return _handle;
  }
}

final class _FormatterSelection {
  final TrackedGridRef start;
  final TrackedGridRef end;
  final TerminalScreen screen;
  final bool rectangle;

  _FormatterSelection(this.start, this.end, this.screen, this.rectangle);

  factory _FormatterSelection.create(Terminal terminal, Selection selection) {
    if (!identical(selection.start._terminal, terminal)) {
      throw ArgumentError.value(
        selection,
        'selection',
        'must belong to formatter terminal',
      );
    }
    final screen = terminal.activeScreen;
    final startPosition = selection.start.positionIn(.screen);
    final endPosition = selection.end.positionIn(.screen);
    if (startPosition == null || endPosition == null) {
      throw ArgumentError.value(
        selection,
        'selection',
        'must be on the active screen',
      );
    }
    final start = TrackedGridRef.at(terminal, startPosition, pointTag: .screen);
    try {
      final end = TrackedGridRef.at(terminal, endPosition, pointTag: .screen);
      return _FormatterSelection(start, end, screen, selection.rectangle);
    } on Object {
      start.dispose();
      rethrow;
    }
  }

  void dispose() {
    start.dispose();
    end.dispose();
  }

  RawSelection snapshot(Terminal terminal) {
    if (terminal.activeScreen != screen) {
      throw StateError('Formatter selection screen is not active');
    }
    final first = start.snapshot();
    final last = end.snapshot();
    if (first == null || last == null) {
      throw StateError('Formatter selection has been invalidated');
    }
    return (start: first._value, end: last._value, rectangle: rectangle);
  }
}

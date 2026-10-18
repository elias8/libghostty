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

  /// Creates a formatter for [terminal].
  ///
  /// [format] selects the output syntax (plain, vt, or html). [extra]
  /// controls which additional terminal state is included in
  /// [FormatterFormat.vt] output (cursor position, modes, palette, etc.);
  /// it has no effect on plain text or HTML output. [selection] restricts
  /// the output to the given range; when null, the entire active screen
  /// is formatted.
  ///
  /// Throws [OutOfMemoryException] when the allocation fails.
  Formatter({
    required Terminal terminal,
    required FormatterFormat format,
    bool unwrap = false,
    bool trim = false,
    FormatterExtra extra = const FormatterExtra(),
    Selection? selection,
  }) : _terminal = terminal,
       _handle = _create(terminal, format, unwrap, trim, extra, selection) {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// Releases the native formatter handle.
  void dispose() {
    final terminal = _terminal;
    if (terminal == null) return;
    bindings.formatter.formatterFree(_handle);
    _finalizer.detach(this);
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
    return bindings.formatter.formatterFormat(handle);
  }

  LibGhosttyHandle _requireHandle() {
    final terminal = _terminal;
    if (terminal == null) throw StateError('Formatter has been disposed');
    if (terminal._disposed) {
      throw StateError('Formatter terminal is disposed');
    }
    return _handle;
  }

  static LibGhosttyHandle _create(
    Terminal terminal,
    FormatterFormat format,
    bool unwrap,
    bool trim,
    FormatterExtra extra,
    Selection? selection,
  ) {
    if (selection == null) {
      return bindings.formatter.formatterTerminalNew(
        terminal._requireHandle(),
        format,
        unwrap: unwrap,
        trim: trim,
        extra: extra,
      );
    }

    if (!identical(selection.start._terminal, terminal)) {
      throw ArgumentError.value(
        selection,
        'selection',
        'must belong to formatter terminal',
      );
    }

    return bindings.formatter.formatterTerminalNew(
      terminal._requireHandle(),
      format,
      unwrap: unwrap,
      trim: trim,
      extra: extra,
      selection: selection._raw,
    );
  }
}

part of 'terminal.dart';

/// A snapshot selection range defined by two grid references.
///
/// Both endpoints are inclusive and preserve direction. [start] may be after
/// [end] in terminal order. When [rectangle] is true, the endpoints are
/// interpreted as opposite corners of a block selection.
///
/// The endpoint refs are untracked snapshots and follow normal [GridRef]
/// lifetime rules. A selection does not track terminal mutations. If the
/// endpoints must survive mutations, keep [TrackedGridRef]s separately and
/// create a fresh [Selection] from their snapshots immediately before use.
///
/// ```dart
/// final start = GridRef.at(terminal, const Position(row: 0, col: 0));
/// final end = GridRef.at(terminal, const Position(row: 0, col: 4));
/// terminal.selection = Selection.fromRefs(start: start, end: end);
/// ```
@immutable
final class Selection {
  /// Start of the selection range, inclusive.
  final GridRef start;

  /// End of the selection range, inclusive.
  final GridRef end;

  /// Whether endpoints describe a rectangular block selection.
  final bool rectangle;

  /// Creates a selection from two grid-reference snapshots.
  ///
  /// Both refs must come from the same [Terminal]. The refs are values and are
  /// not consumed by the selection. The created selection follows normal
  /// [GridRef] lifetime rules. Do not reuse it after mutating the terminal.
  factory Selection.fromRefs({
    required GridRef start,
    required GridRef end,
    bool rectangle = false,
  }) {
    if (!identical(start._terminal, end._terminal)) {
      throw ArgumentError.value(end, 'end', 'must belong to start terminal');
    }
    return Selection._(start, end, rectangle);
  }

  const Selection._(this.start, this.end, this.rectangle);

  Selection._fromRaw(Terminal terminal, RawSelection selection)
    : this._(
        GridRef._fromValue(terminal, selection.start),
        GridRef._fromValue(terminal, selection.end),
        selection.rectangle,
      );

  @override
  int get hashCode => Object.hash(Selection, start, end, rectangle);

  /// The current endpoint order.
  SelectionOrder get order {
    final terminal = start._terminal;
    return bindings.selection.terminalSelectionOrder(
      terminal._requireHandle(),
      _raw,
    );
  }

  RawSelection get _raw {
    return (start: start._value, end: end._value, rectangle: rectangle);
  }

  @override
  bool operator ==(Object other) =>
      other is Selection &&
      other.start == start &&
      other.end == end &&
      other.rectangle == rectangle;

  /// Moves the logical end endpoint by [adjustment].
  Selection adjust(SelectionAdjust adjustment) {
    final terminal = start._terminal;
    return Selection._fromRaw(
      terminal,
      bindings.selection.terminalSelectionAdjust(
        terminal._requireHandle(),
        _raw,
        adjustment,
      ),
    );
  }

  /// Whether this selection includes [position].
  bool contains(Position position, {PointTag pointTag = .active}) {
    final terminal = start._terminal;
    return bindings.selection.terminalSelectionContains(
      terminal._requireHandle(),
      _raw,
      pointTag,
      position,
    );
  }

  /// Whether this selection is equal to [other] according to libghostty.
  bool equal(Selection other) {
    final terminal = start._terminal;
    _checkSameTerminal(other, terminal);
    return bindings.selection.terminalSelectionEqual(
      terminal._requireHandle(),
      _raw,
      other._raw,
    );
  }

  /// Formats this selection.
  String format({
    FormatterFormat format = .plain,
    bool unwrap = false,
    bool trim = false,
  }) {
    final terminal = start._terminal;
    return bindings.selection.terminalSelectionFormat(
      terminal._requireHandle(),
      format,
      unwrap: unwrap,
      trim: trim,
      selection: _raw,
    )!;
  }

  /// Returns this selection with endpoints ordered as [desired].
  Selection ordered(SelectionOrder desired) {
    final terminal = start._terminal;
    return Selection._fromRaw(
      terminal,
      bindings.selection.terminalSelectionOrdered(
        terminal._requireHandle(),
        _raw,
        desired,
      ),
    );
  }

  @override
  String toString() {
    return 'Selection($start -> $end${rectangle ? ', rectangle' : ''})';
  }

  void _checkSameTerminal(Selection other, Terminal terminal) {
    if (!identical(other.start._terminal, terminal)) {
      throw ArgumentError.value(
        other,
        'other',
        'must belong to this selection terminal',
      );
    }
  }
}

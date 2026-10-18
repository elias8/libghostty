part of 'terminal.dart';

/// Searches terminal contents, including scrollback on the primary screen.
///
/// A search borrows its [Terminal], which must remain alive until this object
/// is disposed. Search work is incremental: call [feed] after terminal
/// mutations and [tick] until [status] is no longer [SearchStatus.running].
final class Search {
  static final _finalizer = Finalizer(bindings.search.searchFree);

  Terminal? _terminal;
  final LibGhosttyHandle _handle;

  /// Creates a search bound to [terminal].
  Search(Terminal terminal)
    : _terminal = terminal,
      _handle = bindings.search.searchNew(terminal._requireHandle()) {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// All discovered matches, ordered newest to oldest.
  List<Selection> get matches => _mapSelections(
    bindings.search.searchGetMatches(_requireHandle(), viewport: false),
  );

  /// Current search needle, or null when no needle is set.
  String? get needle => bindings.search.searchGetNeedle(_requireHandle());

  /// Selected match index, ordered from newest to oldest, or null.
  int? get selectedIndex {
    return bindings.search.searchGetSelectedIndex(_requireHandle());
  }

  /// The selected match, or null when no match is selected.
  Selection? get selectedMatch {
    return _mapSelection(
      bindings.search.searchGetSelectedMatch(_requireHandle()),
    );
  }

  /// Scroll policy used when selecting the next or previous match.
  SearchScroll get selectScroll {
    return bindings.search.searchGetSelectScroll(_requireHandle());
  }

  set selectScroll(SearchScroll value) {
    bindings.search.searchSetSelectScroll(_requireHandle(), value);
  }

  /// Current search status.
  SearchStatus get status => bindings.search.searchGetStatus(_requireHandle());

  /// Number of matches on the active screen discovered so far.
  int get totalMatches {
    return bindings.search.searchGetTotalMatches(_requireHandle());
  }

  /// Matches covering the viewport, suitable for drawing highlights.
  List<Selection> get viewportMatches => _mapSelections(
    bindings.search.searchGetMatches(_requireHandle(), viewport: true),
  );

  /// Releases search resources. Calling this more than once is safe.
  void dispose() {
    final terminal = _terminal;
    if (terminal == null) return;
    bindings.search.searchFree(_handle);
    _finalizer.detach(this);
    _terminal = null;
  }

  /// Reads terminal state into the search and returns the current status.
  SearchStatus feed() {
    final handle = _requireHandle();
    bindings.search.searchFeed(handle);
    return status;
  }

  /// Feeds and processes the search until it is complete.
  void run() => bindings.search.searchRun(_requireHandle());

  /// Selects the next older match, wrapping at the oldest match.
  void selectNext() {
    bindings.search.searchSelectNext(_requireHandle());
    _terminal!._notifyListenersFromSearch();
  }

  /// Selects the previous newer match, wrapping at the newest match.
  void selectPrevious() {
    bindings.search.searchSelectPrevious(_requireHandle());
    _terminal!._notifyListenersFromSearch();
  }

  /// Sets or clears the search needle.
  void setNeedle(String? value) {
    bindings.search.searchSetNeedle(_requireHandle(), value);
  }

  /// Performs one bounded unit of search work.
  SearchStatus tick() => bindings.search.searchTick(_requireHandle());

  Selection? _mapSelection(RawSelection? value) {
    return value == null ? null : Selection._fromRaw(_terminal!, value);
  }

  List<Selection> _mapSelections(List<RawSelection> values) => [
    for (final value in values) Selection._fromRaw(_terminal!, value),
  ];

  LibGhosttyHandle _requireHandle() {
    final terminal = _terminal;
    if (terminal == null) throw StateError('Search has been disposed');
    if (terminal._disposed) throw StateError('Search terminal is disposed');
    return _handle;
  }
}

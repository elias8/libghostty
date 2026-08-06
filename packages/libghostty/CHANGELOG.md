# Changelog

## 0.0.12

### Breaking

- **Kitty temporary-file images**: `Terminal.kittyTempFileDirectory` and
  `Terminal.setKittyTempFileDirectory()` replace the boolean temporary-file
  medium API. Loading is restricted to the configured directory, and passing
  null disables the medium.

### Added

- **Clipboard writes**: `Terminal.onClipboardWrite` exposes atomic,
  binary-safe OSC 52 and iTerm2 clipboard requests with normalized locations
  and MIME representations. Clipboard reads remain disabled.
- **Scrollback compression**: `Terminal.compress()` and
  `Terminal.compressionActivity` support incremental or full compression of
  eligible scrollback storage and report unsupported targets.
- **Terminal geometry**: `Terminal.geometry` returns cell and pixel dimensions
  in one query.
- **VT processing diagnostics**: `Terminal.hasVtProcessingError` reports
  errors during terminal-owned semantic updates that cannot be handled
  gracefully.
- **Kitty image usage hints**: transient images are prioritized for eviction
  under memory pressure.

### Changed

- **Resize side effects**: `Terminal.resize()` updates cell pixel geometry,
  disables synchronized output, and emits an in-band size report when mode
  2048 is enabled.
- **Batched state queries**: `RenderState`, `RowIterator`, `CellIterator`,
  `SelectionGesture`, and Kitty graphics reads use consolidated native and WASM
  queries to reduce binding overhead.
- **Formatter allocations**: `Formatter` and `Terminal.formatSelection()` reuse
  growable buffers instead of allocating a native result for each call.
- **Kitty graphics processing**: large APC payloads are dispatched in bulk,
  reducing VT processing overhead for image transfers.
- **Terminal callback errors**: `Terminal.write()` and callback-emitting
  `Terminal.resize()` rethrow the first effect error after processing completes.

### Fixed

- **Resize failure consistency**: failed resizes preserve screen dimensions,
  tab stops, pixel geometry, and synchronized-output state.
- **Selection and grid boundaries**: selection gestures, cloned selections,
  and grid references clamp or reject invalid coordinates across mixed-width
  pages, row boundaries, and extreme input values instead of failing at
  runtime.
- **Page traversal and references**: count-limited traversal crosses page
  boundaries correctly, and row shifts, splits, erasures, and replacements
  invalidate stale page references.
- **Terminal boundary inputs**: empty cell and tab-stop ranges, minimum scroll
  deltas, oversized cursor positions, and non-monotonic selection timestamps
  are handled without runtime safety failures.
- **Source builds in tagged repositories**: compiling Ghostty from source no
  longer reads a consuming application's Git tag, preventing tagged builds
  with non-Ghostty version formats from failing.

## 0.0.11

### Added

- **Color utilities**: `parseColor`, `parsePaletteEntry`,
  `parseX11ColorName`, `x11ColorNames`, palette generation, and luminance
  helpers expose Ghostty's runtime color behavior.
- **Unicode width utilities**: `unicodeCodepointWidth` and
  `unicodeGraphemeWidth` expose Ghostty's terminal cell-width rules.
- **Color-scheme reports**: `ColorScheme.encode()` encodes terminal
  color-scheme reporting responses.
- **Kitty graphics cache stamps**: `KittyGraphics.generation` and
  `KittyImage.generation` let renderers detect placement and image cache
  invalidation without comparing image bytes.
- **Absolute viewport scrolling**: `Terminal.scrollToRow()` restores viewport
  positions using the same row space as `Scrollbar.offset`.

### Changed

- **Kitty graphics pixel data**: stored image payloads are exposed as decoded,
  decompressed pixels, including PNG and zlib-compressed transmissions.
- **Scrollbar metadata**: scrollbar reads use Ghostty's cached offset and
  incrementally maintained total, reducing repeated scrollback traversal.

## 0.0.10

### Breaking

- **Position coordinates**: cursor and grid lookup APIs use `Position`
  values. `GridRef.positionIn()` replaces `pointIn()`, and `GridRef`
  no longer needs `dispose()`.

### Added

- **Selection APIs**: `Selection`, `SelectionGesture`, active terminal
  selection, and selection formatting expose libghostty selection behavior.
- **Tracked grid references**: `TrackedGridRef` follows a cell across
  terminal mutations until the referenced cell is discarded.
- **Terminal APIs**: working-directory changes, device attributes queries,
  default cursor blink, and Glyph Protocol toggling are exposed.
- **Render selection metadata**: `RowIterator.selection` and
  `CellIterator.isSelected`
  expose row-local selection state for render snapshots.

## 0.0.9

### Added

- **Back-arrow key mode**: `TerminalMode.backArrowKeyMode()` and
  `KeyEncoder.setBackArrowKeyMode()` expose DEC mode 67, letting legacy
  Backspace encoding switch between DEL and BS.
- **APC buffer limits**: `Terminal.setApcBufferLimit()` and
  `Terminal.setKittyApcBufferLimit()` configure general and Kitty-specific
  APC payload limits.

### Fixed

- **Resize callbacks**: `ghostty_terminal_resize` is no longer bound as a
  leaf FFI call, preventing callback crashes when resize emits in-band size
  reports through `onWritePty`.

## 0.0.8

### Breaking

- **Standalone companions**: rendering, grid lookups, formatting, and
  encoding moved off `Terminal`. `RenderState` with `RowIterator` /
  `CellIterator`, `GridRef.at`, `Formatter`, `KittyGraphics.of`, and
  standalone `KeyEncoder` / `MouseEncoder` replace their `Terminal`
  method and getter equivalents.

### Added

- **Kitty graphics**: image and placement lookup with resolved render
  geometry, plus a process-global PNG decoder hook.
- **Log callback**: process-global sink for the native library's
  internal log output.
- **Formatter selection**: restrict output to a coordinate region,
  including block selections.
- **Terminal data**: `cursorStyle`, `isMouseTracking`, and Kitty image
  configuration accessors.
- **Grid references**: `hyperlinkUri` and `pointIn()` for OSC 8 lookup
  and coordinate round-tripping.

## 0.0.7

### Fixed

- **Linux prebuilts**: the prebuilt Linux binaries failed to load on glibc
  systems with `invalid ELF header`. They now ship as
  `libghostty-x86_64-linux-gnu.so` and `libghostty-aarch64-linux-gnu.so`,
  properly linked against glibc.

## 0.0.6

### Added

- **ARGB color accessors**: `Cell.backgroundArgb` and `Cell.foregroundArgb`
  return resolved colors as packed 32-bit ARGB ints, or `null` if unset.
  Callers handle the default themselves.
- **`RgbColor.toArgb32`**: convert an `RgbColor` to a packed 32-bit ARGB int
  with full opacity.
- **`Cell.graphemeLength`**: number of codepoints in the cell's grapheme
  cluster (0 for empty cells).

### Changed

- **Cell hot path**: `codepoint` and `wide` are cached during row iteration
  to eliminate per-access FFI calls in the renderer hot loop.
- **Row hot path**: the raw row pointer is cached and invalidated when the
  iterator advances to a new row.

### Fixed

- **VS16 emoji width**: multi-codepoint graphemes are no longer misclassified
  as narrow based on their first codepoint. The wide-cell fast path now only
  applies to single-codepoint cells, so an emoji base followed by VS16 is
  correctly marked wide.
- **Wide-codepoint heuristic**: replaced the hand-rolled Unicode range table
  in the wide-cell fast path with a single `>= U+1100` check. The old table
  could mark some wide CJK codepoints as narrow without consulting the FFI
  width query.

## 0.0.5

### Breaking

- **Upstream C API migration**: replaced the custom `terminal-c-api.patch`
  with upstream Ghostty's natively exposed C headers. This is a complete
  rewrite of the bindings and implementation layer.
- **Restructured public API**: the package barrel (`libghostty.dart`) has a
  new export structure. Most types have been renamed or moved.
- **Removed types**: `Line`, `Screen`, `Scrollback`, `TerminalOptions`,
  `TerminalEvent`, `TerminalModes`, `Disposable`, `Result`.
- **Removed sub-barrels**: `input.dart` and `parsing.dart` are removed.
  Import everything from `libghostty.dart`.

### Added

- **Mouse encoding**: `MouseEncoder` and `MouseEvent` for encoding mouse
  events into terminal escape sequences (X10, UTF-8, SGR, URxvt, SGR-Pixels).
- **Build info**: `LibGhosttyBuildInfo` exposes compile-time feature flags
  (SIMD, Kitty graphics, tmux passthrough) and version info.
- **Terminal modes**: `TerminalMode` provides typed access to DEC private
  and ANSI modes with DECRPM report encoding.
- **Render state**: `RenderState` for efficient viewport snapshotting with
  two-layer dirty tracking (global + per-row).
- **Grid references**: `GridRef` for ad-hoc cell lookups by coordinate.
- **Formatter**: `Formatter` for serializing terminal content as plain text,
  HTML, or full VT state.
- **Terminal effects**: callback-based event model (`onWritePty`, `onBell`,
  `onTitleChanged`, etc.) replacing the `TerminalEvent` stream.
- **Focus and size report encoding**: `FocusEventEncode` and
  `SizeReportStyleEncode` extension types.
- **Programmatic ffigen**: replaced declarative `ffigen.yaml` with a Dart
  driver that generates three specialized output files (native FFI, enums,
  WASM typed exports).

### Changed

- Bumped upstream ghostty to `b7e56044d`.
- Generated enums replace hand-written `src/enums/` directory.
- Bindings reorganized into `native/`, `wasm/`, and `types/` directories.
- Implementation layer reorganized into `src/impl/` with `key/`, `mouse/`,
  and `terminal/` subdirectories.

## 0.0.4

### Added

- **Hyperlink support**: `Cell` and `ScrollbackRow` expose OSC 8 hyperlink
  URIs via a `hyperlink` field.
- **Screen mode**: `TerminalModes` exposes `screenMode` to distinguish
  primary and alternate screen.
- **Mouse alternate scroll**: `TerminalModes` exposes `mouseAlternateScroll`
  flag.
- **Mods toggle operator**: `^` operator on `Mods` for bitwise XOR toggling
  of modifier flags.

### Fixed

- **Scrollback on alternate screen**: `scrollbackLength` returns zero when
  the terminal is on the alternate screen instead of stale values.

### Changed

- Bumped upstream ghostty to `04fa71e23`.

## 0.0.3

### Added

- **iOS simulator support**: prebuilt binaries for `aarch64-ios-simulator`
  and `x86_64-ios-simulator`.

### Fixed

- **Asset hash validation**: reject prebuilt binaries with no known hash
  instead of silently accepting them.

## 0.0.2

### Added

- **Sealed `TerminalEvent` hierarchy**: typed events (`BellReceived`,
  `TitleChanged`, `CursorChanged`, `MouseShapeChanged`, `ResponseReceived`,
  `ScreenChanged`, `ModeChanged`) replace ad-hoc state polling.
- **`TerminalOptions`**: configure foreground/background color and scrollback
  limit at terminal creation.
- **Mouse support**:`MouseShape` and `MouseTracking` exposed via the
  terminal API.
- **`DirtyState` enum**:`clean`/`partial`/`full` for render-level dirty
  tracking on `Screen`.
- **Reusable viewport buffer**:`Screen` reuses a single buffer across reads,
  reducing per-frame allocations.
- **Row wrapping detection**:`Screen` and `Scrollback` report whether a row
  is soft-wrapped.
- **Scrollback grapheme support**:`Scrollback` returns full grapheme
  clusters.
- **`CellWidth` and `SemanticContent`**: new cell metadata types.
- **256-color palette**: CIELAB interpolation and full 256-color palette
  generation with base16 theme support.

### Changed

- **`TerminalViewport` removed**: viewport reading now lives on `Screen`
  directly.
- Bumped upstream ghostty to `055ed285`.

## [0.0.1] - 2026-02-25

### Added

- **Terminal emulation**: Full VT parser and screen buffer
    - Screen, Line, Cell API for inspecting terminal content
    - Cursor control and styling
    - Terminal modes tracking
    - Scrollback buffer support
- **Key encoding**: Kitty keyboard protocol implementation
    - KeyEvent, KeyAction, Mods for key handling
    - KeyEncoder for encoding key events to bytes
- **SGR parsing**: Parse Select Graphic Rendition escape sequences
- **OSC parsing**: Parse Operating System Commands (window title, hyperlinks)
- **Paste validation**: Security-focused paste validation to prevent injection attacks
- **WASM support**: WebAssembly build for browser environments

### Supported Platforms

- Android, iOS, macOS, Linux, Windows, Web

## 0.0.1-dev.3

- Fix release artifact filenames and download URLs

## 0.0.1-dev.2

- Add release automation with build and release workflows
- Add download_asset_hashes.dart script for preparing releases

## 0.0.1-dev.1

- Initial pre-release

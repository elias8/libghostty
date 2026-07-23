# Changelog

## Unreleased

### Fixed

- **Windows keyboard input**: the text input client now reports the hosting
  `FlutterView` id when attaching, so desktop embedders can resolve the
  target view. This fixes typing being dead on Windows, where the attach
  failed with `Could not set client, view ID is null.`.

## 0.0.4

### Breaking

- **Selection APIs**: selection is backed by libghostty. `TerminalSelection`
  and `TerminalSelectionMode` are removed, `TerminalConfig.wordPattern`
  moves to `TerminalGestureSettings.wordBoundaries`, and gesture toggles
  are explicit settings.

### Added

- **Terminal links**: `TerminalView.linkSettings` detects OSC 8 links,
  text URLs, file paths, and custom regex links.
- **Controller APIs**: `selectRange`, `hasSelection`, `pwd`, and
  `onPwdChanged` expose selection and working-directory state.
- **Glyph Protocol**: `TerminalConfig.glyphProtocol` toggles Glyph Protocol
  APC handling.

### Changed

- **Rendering pipeline**: selection, cursor viewport state, and cell metadata
  use refreshed libghostty render snapshots.

## 0.0.3

### Breaking

- **Flutter SDK floor**: requires Dart 3.12 and Flutter 3.44.

### Added

- **IME composition**: composing text appears at the terminal cursor
  and works with platform text input.
- **Sprite glyph rendering**: box drawing, block elements, Braille,
  Powerline, geometric shapes, and legacy computing glyphs render
  with built-in glyphs.
- **Shared render caches**: `TerminalScope` lets multiple terminal
  views share compatible rendering resources.
- **APC buffer limits**: `TerminalConfig.apcBufferLimit` controls how
  much APC payload data the terminal accepts.

### Changed

- **Rendering pipeline**: terminal frames share rendering caches and do
  less repeated work between frames.

### Fixed

- **Keyboard input**: shifted printable keys and IME editing produce
  the expected terminal text.
- **Rendering accuracy**: erased backgrounds, cursor shape, cell
  metrics, and sprite glyphs render more consistently.

## 0.0.2

### Breaking

- **Theme colors move into `ColorPalette`**: `TerminalTheme` no longer
  takes `background`, `foreground`, and `ansiColors` directly. Build a
  `ColorPalette` once and pass it in, so palettes are something you
  can share, swap, or `copyWith` on their own.
- **Cursor and selection colors can adapt to the cell under them**: the
  color fields take `DynamicColor?` now. Use
  `DynamicColor.cellForeground()` / `.cellBackground()` to follow the
  cell, or `DynamicColor.fixed(c)` for the old static behavior.
- **`selectedText` is a method**: call `controller.selectedText()` for
  plain text, or pass a `FormatterFormat` to get VT or HTML for
  rich-clipboard copy.
- **Bold no longer switches to the bright palette by default**: expect
  slightly different bold colors; set `boldIsBright: true` to restore
  the old behavior.

### Added

- **Kitty graphics**: programs that emit images (previewers, image
  viewers, some editors) render inside the widget. Cap the cache via
  `TerminalConfig.kittyImageStorageLimit`; zero disables.
- **Transparent background**: `TerminalTheme.backgroundOpacity` makes
  the default background translucent so the terminal can compose over
  a translucent window or other widgets. `backgroundOpacityCells`
  extends it to cells with their own bg color.
- **More theme knobs**: `CursorTheme.text` (glyph color under a block
  cursor), `TerminalTheme.boldColor` (forced bold color), and
  `SelectionTheme.foreground` (selected-glyph tint).
- **`ColorPalette.generated()`**: derives indices 16–255 from your base
  16 plus background and foreground so the extended palette blends
  instead of clashing with the fixed xterm cube.

### Changed

- **Dirty-row rendering**: frames rebuild only rows that changed, so
  idle terminals cost much less CPU.

## 0.0.1

Initial release.

### Added

- **`TerminalView`**: a Flutter widget that renders a terminal and
  adapts its input to the host. Mouse and keyboard on desktop, touch
  and soft keyboard on mobile, both on web.
- **`TerminalController`**: owns the terminal and bridges it with the
  view. Connects to a backend (PTY, SSH, socket) via `onOutput`,
  `onResize`, `onBell`, and `onTitleChanged`. Exposes I/O (`write`,
  `sendText`, `sendKey`), selection (`selectAll`, `selectWord`,
  `selectLine`), focus, scrolling, paste, clear, and mode toggling.
- **Themes**: ANSI 16, 256-color, and truecolor palettes; cursor
  shape, color, and blink; hyperlink style; font family, size, and
  fallback; minimum contrast. Immutable and `lerp`-able.
- **Wide characters**: CJK, color emoji, VS16, and combining marks
  render correctly; selection snaps to whole cells.
- **Mouse selection**: drag, double-click word, triple-click line,
  and Alt+drag block. Configurable via `TerminalGestureSettings`.
- **Shortcuts**: built-in copy, paste, select all, and clear with
  platform-aware defaults (Cmd on macOS/iOS, Ctrl+Shift on
  Linux/Windows). Extend or replace with any Flutter `Intent`.
- **OSC 8 hyperlinks**: idle and highlighted styles with click
  hit-testing.
- **Cross-platform**: Android, iOS, Linux, macOS, Web (WASM), Windows.

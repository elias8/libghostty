# Changelog

## 0.0.6

### Breaking

- **Scrollback limits**: replace `TerminalConfig.scrollbackLimit` with
  `scrollbackMaxBytes` and optional `scrollbackMaxLines`. The default byte
  limit changes from 10,000,000 to 10,000. Set
  `scrollbackMaxBytes: 10_000_000` to preserve the previous budget, or use
  null for no byte limit.
- **Controller extensibility**: `TerminalController` is sealed. Create sessions
  through its factories and use composition instead of custom subclasses or
  implementations.
- **Focus and keyboard control**: controller focus methods, keyboard methods,
  and `keyboardState` are removed. Pass a `FocusNode` to `TerminalView` for
  imperative focus control and configure soft-keyboard access with
  `TerminalView.showKeyboard`.
- **Controller contract**: `TerminalController` supports one attached
  `TerminalView`. A second concurrent attachment throws `StateError`.
- **Callback configuration**: `onBell`, `onOutput`, `onPwdChanged`, `onResize`,
  and `onTitleChanged` are setter-only. Retain callback references if their
  identity is needed elsewhere.
- **Clipboard payloads**: re-exported `ClipboardContent` and `ClipboardWrite`
  are immutable classes. Replace record literals with their constructors and
  use named fields.
- **Removed public types**: `KeyboardState` and `TerminalScrollPosition` are no
  longer exported. Use `FocusNode`, `TerminalView.showKeyboard`, and the
  standard `ScrollPosition` interface.

### Added

- **Terminal snapshots**: `TerminalController.snapshot()` captures libghostty
  state, and `TerminalController.fromSnapshot()` restores it progressively or
  synchronously. `restoration` exposes lifecycle state, while the
  `restored` future reports completion and late errors. Continuation tracking
  preserves incomplete VT and UTF-8 input. Restoration can compress history,
  preserve snapshot colors, and defer resizing while scrollback loads.
- **Terminal search**: `TerminalController.search` manages incremental searches,
  match navigation, scroll policy, and automatic viewport highlighting.
  `TerminalTheme.search` styles ordinary and selected matches, while
  `TerminalView.overlayBuilder` and `TerminalViewGeometry` support custom,
  cell-aware search interfaces.
- **Touch selection handles**: Android and iOS long-press selections expose
  draggable platform-styled endpoint handles with adaptive magnifiers and edge
  autoscroll. Toggling the configured block-selection modifier while dragging
  switches between normal and rectangular selection. Configure or disable
  magnification through `TerminalGestureSettings`.
- **Clipboard reads**: `TerminalController.onClipboardRead` forwards
  MIME-aware terminal requests for application-controlled clipboard access.
- **Session events**: callbacks expose desktop notifications, progress,
  program status, semantic prompts, full resets, and unknown sequences.
- **Terminal metadata**: controllers expose memory usage and requested mouse
  shapes; views reflect terminal-requested pointer shapes.
- **Prompt navigation**: `TerminalController.scrollToPrompt()` navigates
  between shell integration prompts.
- **Resource controls**: applications can limit retained snapshot continuation
  bytes, captured unknown sequences, and clipboard-write payloads.
- **Terminal compatibility**: disable restoring scrollback rows during resize
  for backends that keep their own screen buffer, or opt into screen checksum
  replies for terminal programs that need them.

### Changed

- **Synchronized output**: views hold complete frames during terminal-driven
  synchronized updates, including cursor and image state. A timeout releases
  abandoned holds, and user interactions release a hold when needed.
- **Rendering memory**: font and glyph caches have bounded memory use across
  terminal views.
- **Resize lifecycle**: `onResize` reports only after `TerminalView` commits a
  measured grid; assigning it later immediately reports that grid.
  Cell-pixel-only changes skip the callback, and in-band output is emitted
  first.

### Fixed

- **Ctrl+Space**: the chord encodes as NUL in legacy mode and as a Kitty
  CSI u chord, allowing applications such as Neovim to receive it.
- **Cursor rendering**: the cursor and composing text no longer appear at an
  invalid viewport position. The cursor follows the terminal's reported style.
- **Text input recovery**: keyboard input resumes after another widget takes
  the platform text input connection, including during IME composition.
- **Keyboard and IME input**: AltGr text no longer sends unintended Control or
  Alt input. Kitty keyboard reports include Caps Lock and Num Lock, and IME
  newline and deletion events no longer duplicate or suppress input.
- **Pointer input**: mouse and stylus button changes remain accurate during a
  gesture, stylus drags select text, and a gesture no longer switches between
  selection and terminal mouse reporting.
- **View updates**: replacing a controller preserves terminal focus, and
  detached controllers can be attached again. Changing `TerminalView.fontData`
  updates text sizing. Selection changes no longer cause notifications during
  widget builds.
- **Terminal glyph rendering**: Nerd Font symbols use common fallback families,
  fit their cell without distortion, and preserve adjacent spacing. Operator
  ligatures remain stable across complete runs, and glyphs that extend beyond
  their cells retain their visible overflow.
- **Kitty graphics**: images no longer disappear or briefly show mismatched
  pixels and dimensions during replacement. Image placements stay aligned
  after layout changes and resizing.

## 0.0.5

### Added

- **Clipboard writes**: `TerminalController.onClipboardWrite` forwards atomic,
  binary-safe OSC 52 and iTerm2 clipboard requests so applications can apply
  their own platform and security policies. If the callback throws, the
  initiating write finishes terminal processing before rethrowing the error.
- **Idle scrollback compression**: attached terminal views schedule bounded
  compression after terminal and viewport activity settles, reducing retained
  scrollback memory without competing with rendering.

### Changed

- **Kitty graphics caching**: unchanged placement snapshots are reused across
  frames, while image generations invalidate cached images and stale pending
  decodes. This avoids repeated traversal, sorting, and eviction work without
  displaying stale image data.
- **Color behavior**: `ColorPalette.generated()` uses libghostty palette
  generation, and terminal color-scheme reports use perceived background
  luminance.
- **Published package contents**: tests, benchmark tooling, generated API
  documentation, build outputs, and coverage data are excluded.

### Fixed

- **IME preedit layout**: ZWJ emoji, skin-tone emoji sequences, combining
  marks, and variation selectors are measured as grapheme clusters using
  libghostty's terminal width rules.
- **Viewport scrolling**: scroll-controller pixel offsets map to absolute
  terminal rows regardless of the current viewport position.
- **Windows text input**: platform text input binds to the `TerminalView`'s
  owning Flutter view and reconnects when that view changes.

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

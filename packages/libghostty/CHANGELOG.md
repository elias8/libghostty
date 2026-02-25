# Changelog

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

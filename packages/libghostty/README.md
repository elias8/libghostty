# libghostty

[![pub package](https://img.shields.io/pub/v/libghostty)](https://pub.dev/packages/libghostty)
[![GitHub Actions](https://github.com/elias8/libghostty/actions/workflows/build.yml/badge.svg)](https://github.com/elias8/libghostty/actions)
[![Sponsor](https://img.shields.io/github/sponsors/elias8?logo=githubsponsors&label=sponsor)](https://github.com/sponsors/elias8)

Dart bindings to [libghostty-vt](https://github.com/ghostty-org/ghostty),
the terminal emulator library from [Ghostty](https://ghostty.org).

| Android | iOS | macOS | Linux | Windows | Web |
|:-------:|:---:|:-----:|:-----:|:-------:|:---:|
|    ✅    |  ✅  |   ✅   |   ✅   |    ✅    |  ✅  |

## Getting started

```yaml
# pubspec.yaml
dependencies:
  libghostty: ^0.0.12
```

On web, initialize the WASM module once before using any bindings:

```dart
await initializeForWeb(Uri.parse('assets/libghostty.wasm'));
```

## Usage

### Terminal

Terminal emulator with screen state, scrollback, cursor, styles, modes, and
VT stream processing. Register effect callbacks for PTY writes, bell, title
changes, and more.

Effects run synchronously during `write` and callback-emitting `resize` calls.
If one or more effects throw, that call finishes processing, notifies its
listeners, and then rethrows its first failure with the original stack. Catch
the initiating call when the host needs to recover.

```dart
import 'dart:typed_data';
import 'package:libghostty/libghostty.dart';

void main() {
  final terminal = Terminal(cols: 80, rows: 24);

  // Register effects (callbacks invoked synchronously during write).
  terminal.onWritePty = (data) => pty.write(data);
  terminal.onBell = () => playSound();
  terminal.onTitleChanged = () => print('Title: ${terminal.title}');

  // Write VT data and resize.
  terminal.write(Uint8List.fromList(vtData));
  terminal.resize(cols: 120, rows: 40, cellWidthPx: 8, cellHeightPx: 16);

  // Read a single cell via grid reference (for ad-hoc lookups).
  final ref = GridRef.at(terminal, const Position(row: 0, col: 0));
  print(ref.content); // the character at (0, 0)

  // Read screen via render state and reusable iterators.
  final renderState = RenderState();
  final rows = RowIterator();
  final cells = CellIterator();

  renderState.update(terminal);
  rows.reset(renderState);
  while (rows.next()) {
    cells.reset(rows);
    while (cells.next()) {
      if (cells.hasText) print(cells.content);
    }
    rows.dirty = false;
  }
  renderState.dirty = DirtyState.clean;

  cells.dispose();
  rows.dispose();
  renderState.dispose();
  terminal.dispose();
}
```

### Key encoding

Encode key events into terminal escape sequences, supporting legacy and Kitty
keyboard protocol.

```dart
final encoder = KeyEncoder();
final event = KeyEvent()
  ..mods = const .ctrl()
  ..action = .press
  ..key = .c;

encoder.sync(terminal); // pick up mode changes before encoding
final encoded = encoder.encode(event);
if (encoded.isNotEmpty) pty.write(utf8.encode(encoded));

event.dispose();
encoder.dispose();
```

### Mouse encoding

Encode mouse events into escape sequences, supporting X10, UTF-8, SGR, URxvt,
and SGR-Pixels protocols.

```dart
final encoder = MouseEncoder()
  ..setSize(const MouseEncoderSize(
    screenWidth: 640,
    screenHeight: 384,
    cellWidth: 8,
    cellHeight: 16,
  ));

final event = MouseEvent()
  ..action = .press
  ..button = .left
  ..setPosition(x: 10.0, y: 5.0);

encoder.sync(terminal); // pick up tracking-mode changes before encoding
final encoded = encoder.encode(event);
if (encoded.isNotEmpty) pty.write(utf8.encode(encoded));

event.dispose();
encoder.dispose();
```

### Formatting

Format terminal content as plain text, VT sequences, or HTML.

```dart
final formatter = Formatter(terminal: terminal, format: .plain);
print(formatter.format());
formatter.dispose();
```

### SGR and OSC parsing

Parse SGR (Select Graphic Rendition) parameters into typed attributes and
OSC (Operating System Command) sequences from a byte stream.

```dart
// SGR: parse Select Graphic Rendition parameters.
final sgr = SgrParser();
for (final attr in sgr.parse([1, 38, 2, 255, 0, 0])) {
  switch (attr.tag) {
    case .bold:
      print('bold');
    case .directColorFg:
      print('fg: ${attr.color}');
    default:
      break;
  }
}
sgr.dispose();

// OSC: parse Operating System Command sequences.
final osc = OscParser();
osc.feedBytes(utf8.encode('0;My Title'));
final command = osc.end(0x07);
print(command.type);        // OscCommandType.changeWindowTitle
print(command.windowTitle); // My Title
osc.dispose();
```

### Paste validation

Check paste data for unsafe sequences (newlines, bracketed paste escapes)
before writing to the terminal.

```dart
pasteIsSafe('hello');           // true
pasteIsSafe('rm -rf /\n');      // false
pasteIsSafe('\x1b[201~inject'); // false
```

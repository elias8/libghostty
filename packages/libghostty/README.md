# libghostty

Dart bindings to [libghostty-vt](https://github.com/ghostty-org/ghostty) — the
virtual terminal emulator library from [Ghostty](https://ghostty.org).

| Android | iOS | macOS | Linux | Windows | Web |
|:-------:|:---:|:-----:|:-----:|:-------:|:---:|
|    ✅    |  ✅  |   ✅   |  🚧   |   🚧    | ⚠️  |

## Getting started

```yaml
dependencies:
  libghostty: ^0.0.1-dev.1
```

```dart
import 'package:libghostty/libghostty.dart';

Future<void> main() async {
  // Required on web only. You can safely call this on other platforms.
  // await initializeForWeb(Uri.parse('assets/ghostty-vt.wasm'));

  final terminal = Terminal(cols: 80, rows: 24);
  terminal.write(Uint8List.fromList('Hello, terminal!\r\n'.codeUnits));

  final cell = terminal.screen.cellAt(0, 0);
  print(cell.content); // H

  terminal.dispose();
}
```

## Usage

### Terminal emulation

```dart
final terminal = Terminal(cols: 80, rows: 24);

terminal.write(Uint8List.fromList('\x1b[1;34mHello\x1b[0m\r\n'.codeUnits));

for (var row = 0; row < terminal.screen.rows; row++) {
  final text = terminal.screen.lineAt(row).text;
  if (text.isNotEmpty) print(text);
}

terminal.dispose();
```

### Key encoding

```dart
final encoder = KeyEncoder();
final event = KeyEvent()
  ..action = KeyAction.press
  ..key = Key.keyC
  ..mods = Mods.ctrl;

print(encoder.encode(event).codeUnits); // [3] (ETX)

event.dispose();
encoder.dispose();
```

### SGR parsing

```dart
final parser = SgrParser();
final attrs = parser.parse([1, 31]);

for (final attr in attrs) {
  switch (attr) {
    case SgrBold():
      print('Bold');
    case SgrForeground8(:final index):
      print('Color: $index');
    default:
      break;
  }
}

parser.dispose();
```

### OSC parsing

```dart
final parser = OscParser();
parser.feedBytes(utf8.encode('0;Window Tile'));
final command = parser.end(0x07);

print(command.type);        // OscCommandType.changeWindowTitle
print(command.windowTitle); // My Title

parser.dispose();
```

### Paste validation

```dart
pasteIsSafe('hello');           // true
pasteIsSafe('rm -rf /\n');      // false
pasteIsSafe('\x1b[201~inject'); // false
```

## Clean up

All native backed objects require `dispose()` when no longer needed. Using 
disposed object throws `DisposedException`. Double dispose is a safe.

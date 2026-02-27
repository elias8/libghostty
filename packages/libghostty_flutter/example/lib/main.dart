import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:libghostty/libghostty.dart';
import 'package:libghostty_flutter/foundation.dart';
import 'package:libghostty_flutter/rendering.dart';

void main() => runApp(const _App());
const _cols = 60;
const _metrics = CellMetrics(cellWidth: 10, cellHeight: 20, baseline: 15);

const _rows = 22;

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const _DemoScreen(),
    );
  }
}

class _DemoScreen extends StatefulWidget {
  const _DemoScreen();

  @override
  State<_DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<_DemoScreen> {
  late final Terminal _terminal;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TerminalTheme.defaults.background,
      body: Center(
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: _cols * _metrics.cellWidth,
              maxHeight: _rows * _metrics.cellHeight,
            ),
            child: TerminalRenderer(
              terminal: _terminal,
              theme: TerminalTheme.defaults,
              metrics: _metrics,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _terminal.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(cols: _cols, rows: _rows);
    _writeDemoContent();
  }

  void _write(String s) => _terminal.write(.fromList(utf8.encode(s)));

  void _writeAnsiColors() {
    _write('  Colors:     ');
    for (var i = 0; i < 8; i++) {
      _write('\x1b[${40 + i}m  \x1b[0m');
    }
    _write(' ');
    for (var i = 0; i < 8; i++) {
      _write('\x1b[${100 + i}m  \x1b[0m');
    }
    _write('\r\n');
  }

  void _writeBoxDrawing() {
    _write('  Box:  ┌───────────┐  Blocks: █▓▒░  ▌▐▄▀\r\n');
    _write('        │ libghostty│  Braille: ⠁⠃⠇⡇⣇⣷⣿ ⠮⢣\r\n');
    _write('        └───────────┘  Geom:    ■□●○◆◇▲▶▷\r\n');
  }

  void _writeBytes(List<int> bytes) {
    _terminal.write(Uint8List.fromList(bytes));
  }

  void _writeDecorations() {
    _write('  Decor:      ');
    _write('\x1b[9mStrike\x1b[0m ');
    _write('\x1b[53mOverline\x1b[0m ');
    _write('\x1b[4;9mUnder+Strike\x1b[0m ');
    _write('\x1b[4m\x1b[58;2;255;80;80mRed underline\x1b[0m\r\n');
  }

  void _writeDemoContent() {
    _write('\x1b[2J\x1b[H');
    _write('\x1b[1m  M2 Rendering Demo — libghostty_flutter\x1b[0m\r\n');
    _write('\r\n');

    _writeTextAttributes();
    _writeUnderlineStyles();
    _writeDecorations();
    _writeAnsiColors();
    _write('  Wide CJK:   日本語  中文  한국어\r\n');
    _write('\r\n');
    _writeBoxDrawing();
    _write('\r\n');
    _writePowerline();
    _write('\r\n');
    _writeSextants();
    _write('\r\n');
    _write('  Cursor below (block, blinking):\r\n');
    _write('\x1b[$_rows;3H');
  }

  void _writePowerline() {
    _write('  Powerline:  ');
    _write('\x1b[44;37m  main \x1b[0m');
    _writeBytes([0xEE, 0x82, 0xB0]);
    _write('\x1b[30;42m src/app.dart \x1b[0m');
    _writeBytes([0xEE, 0x82, 0xB0]);
    _write('\x1b[37;40m\r\n');
  }

  void _writeSextants() {
    _write('  Sextants:   ');
    for (var i = 0; i < 8; i++) {
      final cp = 0x1FB00 + i;
      _writeBytes([
        0xF0 | (cp >> 18),
        0x80 | ((cp >> 12) & 0x3F),
        0x80 | ((cp >> 6) & 0x3F),
        0x80 | (cp & 0x3F),
      ]);
    }
    _write('\r\n');
  }

  void _writeTextAttributes() {
    _write('  Attributes: ');
    _write('\x1b[1mBold\x1b[0m ');
    _write('\x1b[3mItalic\x1b[0m ');
    _write('\x1b[2mFaint\x1b[0m ');
    _write('\x1b[7mInverse\x1b[0m ');
    _write('\x1b[1;3mBold+Italic\x1b[0m\r\n');
  }

  void _writeUnderlineStyles() {
    _write('  Underline:  ');
    _write('\x1b[4mSingle\x1b[0m ');
    _write('\x1b[4:2mDouble\x1b[0m ');
    _write('\x1b[4:3mCurly\x1b[0m ');
    _write('\x1b[4:4mDotted\x1b[0m ');
    _write('\x1b[4:5mDashed\x1b[0m\r\n');
  }
}

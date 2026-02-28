// ignore_for_file: avoid_print
@Tags(['benchmark', 'ffi'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart';
import 'package:libghostty_flutter/foundation.dart';
import 'package:libghostty_flutter/rendering.dart';

/// Rendering pipeline benchmark.
///
/// Measures full-screen and partial-row rebuild times across standard
/// terminal sizes. Run with:
///
/// ```bash
/// flutter test test/rendering/benchmark/paint_benchmark.dart
/// ```
///
/// Results are printed as a table with p50/p95/p99 latencies, a p95 target
/// derived from the 8ms frame budget (120fps), and the delta from target.
void main() {
  final results = <_Result>[];

  tearDownAll(() => _printReport(results));

  for (final (:cols, :rows) in _sizes) {
    final size = '$cols×$rows';

    testWidgets('full rebuild $size', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      final terminal = Terminal(cols: cols, rows: rows);
      addTearDown(terminal.dispose);

      await tester.pumpWidget(_buildWidget(terminal, cols, rows));
      terminal.write(_fillScreen(cols, rows, 0));
      await tester.pump();

      final durations = await _timedPumps(tester, (i) {
        terminal.write(_fillScreen(cols, rows, i % 26));
      });

      results.add(_measure('full', size, durations));
    });

    testWidgets('partial 3-row rebuild $size', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      final terminal = Terminal(cols: cols, rows: rows);
      addTearDown(terminal.dispose);

      terminal.write(_fillScreen(cols, rows, 0));
      await tester.pumpWidget(_buildWidget(terminal, cols, rows));
      await tester.pump();

      var counter = 0;
      final durations = await _timedPumps(tester, (_) {
        final sb = StringBuffer();
        for (var r = 0; r < 3; r++) {
          sb.write('\x1b[${r + 1};1H');
          sb.write('row${r}_iter${counter++}'.padRight(cols - 1));
        }
        terminal.write(Uint8List.fromList(utf8.encode(sb.toString())));
      });

      results.add(_measure('partial-3', size, durations));
    });
  }
}

const _iterations = 50;
const _metrics = CellMetrics(cellWidth: 8, cellHeight: 16, baseline: 12);
const _sizes = [
  (cols: 80, rows: 24),
  (cols: 120, rows: 40),
  (cols: 200, rows: 60),
];
const _targets = {
  ('full', '80×24'): 4000,
  ('partial-3', '80×24'): 2000,
  ('full', '120×40'): 8000,
  ('partial-3', '120×40'): 4000,
  ('full', '200×60'): 16000,
  ('partial-3', '200×60'): 6000,
};

Widget _buildWidget(Terminal terminal, int cols, int rows) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: cols * _metrics.cellWidth,
          maxHeight: rows * _metrics.cellHeight,
        ),
        child: TerminalRenderer(
          terminal: terminal,
          theme: TerminalTheme.defaults,
          metrics: _metrics,
        ),
      ),
    ),
  );
}

Uint8List _fillScreen(int cols, int rows, int variant) {
  final sb = StringBuffer();
  for (var row = 0; row < rows; row++) {
    sb.write('\x1b[${row + 1};1H');
    for (var col = 0; col < cols - 1; col++) {
      sb.writeCharCode(0x41 + (col + variant) % 26);
    }
  }
  return Uint8List.fromList(utf8.encode(sb.toString()));
}

_Result _measure(String type, String size, List<int> durations) {
  final sorted = [...durations]..sort();
  return (
    type: type,
    size: size,
    median: sorted[sorted.length ~/ 2],
    worst5: sorted[(sorted.length * 0.95).ceil() - 1],
  );
}

String _ms(int us) => '${(us / 1000).toStringAsFixed(1)}ms';

void _printReport(List<_Result> results) {
  final buf = StringBuffer()
    ..writeln()
    ..writeln('Paint Benchmark')
    ..writeln(
      '$_iterations iterations per test, '
      'update + paint, budget = 8ms (120fps)',
    )
    ..writeln()
    ..writeln(
      '${'Test'.padRight(22)} '
      '${'Median'.padLeft(8)}  '
      '${'Worst 5%'.padLeft(8)}  '
      '${'Budget'.padLeft(8)}  '
      '${'vs Budget'.padLeft(9)}',
    )
    ..writeln(
      '${'─' * 22} '
      '${'─' * 8}  '
      '${'─' * 8}  '
      '${'─' * 8}  '
      '${'─' * 9}',
    );
  for (final r in results) {
    final target = _targets[(r.type, r.size)]!;
    final label = '${r.size.padRight(8)} ${r.type}';
    final delta = ((r.worst5 - target) / target * 100).round();
    final deltaStr = delta <= 0 ? '$delta%' : '+$delta%';
    buf.writeln(
      '${label.padRight(22)} '
      '${_ms(r.median).padLeft(8)}  '
      '${_ms(r.worst5).padLeft(8)}  '
      '${_ms(target).padLeft(8)}  '
      '${deltaStr.padLeft(9)}',
    );
  }
  buf.writeln();
  print(buf);
}

Future<List<int>> _timedPumps(
  WidgetTester tester,
  void Function(int i) prepare,
) async {
  final durations = <int>[];
  final sw = Stopwatch();
  for (var i = 0; i < _iterations; i++) {
    prepare(i);
    sw
      ..reset()
      ..start();
    await tester.pump();
    sw.stop();
    durations.add(sw.elapsedMicroseconds);
  }
  return durations;
}

typedef _Result = ({String type, String size, int median, int worst5});

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../fixture/terminal.dart';
import '../input_benchmark.dart';
import '../protocol.dart';
import '../report/model.dart';
import 'harness.dart';

/// Owns workload registration and result collection for one profile run.
///
/// ```dart
/// FltermBenchmarkSuite(binding).register();
/// ```
final class FltermBenchmarkSuite {
  final IntegrationTestWidgetsFlutterBinding _binding;

  const FltermBenchmarkSuite(this._binding);

  void register() {
    group('flterm performance', () {
      group('input throughput', () {
        testWidgets('records public controller workloads', (tester) async {
          final results = runControllerWriteBenchmarks();

          _record(results);

          expect(results, hasLength(2));
        });
      });

      group('frame rendering', () {
        testWidgets('records clean frames', (tester) async {
          final harness = await _harness(tester);

          final result = await harness.measureSteadyFrames(
            workload: .cleanFrame,
          );
          _record([result]);

          _expectCapturedFrames(result, benchmarkSteadyFrames);
        });

        testWidgets('records partial TUI updates', (tester) async {
          final harness = await _harness(tester);
          final updates = TerminalBenchmarkFixture.partialFrames(
            count: benchmarkSteadyFrames,
          );

          final result = await harness.measureSteadyFrames(
            workload: .partialTui,
            updates: updates,
          );
          _record([result]);

          _expectCapturedFrames(result, benchmarkSteadyFrames);
        });

        testWidgets('records full-screen output', (tester) async {
          final harness = await _harness(tester);
          final updates = TerminalBenchmarkFixture.fullFrames(
            count: benchmarkSteadyFrames,
          );

          final result = await harness.measureSteadyFrames(
            workload: .fullOutput,
            updates: updates,
          );
          _record([result]);

          _expectCapturedFrames(result, benchmarkSteadyFrames);
        });

        testWidgets('records glyph cache misses', (tester) async {
          final harness = await _harness(tester);

          final result = await harness.measureGlyphMissFrames();
          _record([result]);

          _expectCapturedFrames(result, benchmarkGlyphMissFrames);
        });

        testWidgets('records first terminal frames', (tester) async {
          final harness = await _harness(tester);

          final result = await harness.measureFirstTerminalFrames();
          _record([result]);

          expect(
            result.details['frame_count'],
            greaterThanOrEqualTo(benchmarkFirstFrameSamples),
          );
        });
      });
    });
  }

  Future<FrameBenchmarkHarness> _harness(WidgetTester tester) async {
    final harness = FrameBenchmarkHarness(_binding, tester);
    await harness.initialize();
    return harness;
  }

  void _expectCapturedFrames(
    BenchmarkWorkloadResult result,
    int scheduledFrames,
  ) {
    final minimum = (scheduledFrames * benchmarkMinimumFrameCaptureRatio)
        .floor();
    expect(result.details['frame_count'], greaterThanOrEqualTo(minimum));
  }

  void _record(List<BenchmarkWorkloadResult> results) {
    final data = _binding.reportData ??= <String, Object?>{};
    final existing = switch (data['workloads']) {
      final List<Object?> values => values,
      null => <Object?>[],
      _ => throw const FormatException('Benchmark workloads must be a list.'),
    };
    data['workloads'] = [
      ...existing,
      for (final result in results) result.toJson(),
    ];
  }
}

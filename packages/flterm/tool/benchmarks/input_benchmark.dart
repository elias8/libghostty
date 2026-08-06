import 'dart:math' show sqrt;
import 'dart:typed_data';

import 'package:flterm/flterm.dart' show TerminalConfig, TerminalController;

import 'fixture/terminal.dart';
import 'protocol.dart';
import 'report/model.dart';

const _interactiveChunkSize = 4 * 1024;
const _streamingChunkSize = 128 * 1024;

/// Measures fixed work after warmup until both sample minima are met.
BenchmarkWorkloadResult measureBenchmark({
  required BenchmarkWorkload workload,
  required void Function() step,
  void Function()? prepare,
  int warmupIterations = 10,
  int minimumSamples = 100,
  Duration minimumDuration = const Duration(seconds: 5),
  int? bytesPerIteration,
  int Function()? clock,
}) {
  if (workload.kind != .input) {
    throw ArgumentError.value(
      workload,
      'workload',
      'must be an input workload',
    );
  }
  if (warmupIterations < 0) {
    throw RangeError.range(warmupIterations, 0, null, 'warmupIterations');
  }
  if (minimumSamples <= 0) {
    throw RangeError.range(minimumSamples, 1, null, 'minimumSamples');
  }
  if (minimumDuration.isNegative) {
    throw ArgumentError.value(minimumDuration, 'minimumDuration');
  }
  if (bytesPerIteration != null && bytesPerIteration <= 0) {
    throw RangeError.range(bytesPerIteration, 1, null, 'bytesPerIteration');
  }
  for (var iteration = 0; iteration < warmupIterations; iteration++) {
    prepare?.call();
    step();
  }

  final readClock = clock ?? _stopwatchClock();
  final samples = <int>[];
  var measuredMicroseconds = 0;
  do {
    prepare?.call();
    final start = readClock();
    step();
    final elapsed = readClock() - start;
    if (elapsed <= 0) {
      throw StateError(
        'Benchmark "${workload.id}" completed below the clock resolution.',
      );
    }
    samples.add(elapsed);
    measuredMicroseconds += elapsed;
  } while (samples.length < minimumSamples ||
      measuredMicroseconds < minimumDuration.inMicroseconds);

  return _workloadResult(
    workload: workload,
    samples: samples,
    bytesPerIteration: bytesPerIteration,
  );
}

/// Measures the public input boundary with realistic precomputed streams.
List<BenchmarkWorkloadResult> runControllerWriteBenchmarks() {
  return [
    _measureWrites(
      workload: .streamingOutput,
      chunks: TerminalBenchmarkFixture.chunks(
        TerminalBenchmarkFixture.streamingOutput,
        _streamingChunkSize,
      ),
    ),
    _measureWrites(
      workload: .interactiveTui,
      chunks: TerminalBenchmarkFixture.chunks(
        TerminalBenchmarkFixture.interactiveTuiOutput,
        _interactiveChunkSize,
      ),
    ),
  ];
}

BenchmarkWorkloadResult _measureWrites({
  required BenchmarkWorkload workload,
  required List<Uint8List> chunks,
}) {
  final controller = TerminalController(
    config: const TerminalConfig(scrollbackMaxBytes: 0),
  );
  try {
    return measureBenchmark(
      workload: workload,
      step: () => _writeChunks(controller, chunks),
      bytesPerIteration: TerminalBenchmarkFixture.corpusLength,
    );
  } finally {
    controller.dispose();
  }
}

int Function() _stopwatchClock() {
  final stopwatch = Stopwatch()..start();
  return () => stopwatch.elapsedMicroseconds;
}

BenchmarkMetric _timingMetric(String id, num microseconds) {
  return BenchmarkMetric(
    id: id,
    label: id,
    value: microseconds / Duration.microsecondsPerMillisecond,
    unit: .milliseconds,
    direction: .lowerIsBetter,
  );
}

BenchmarkWorkloadResult _workloadResult({
  required BenchmarkWorkload workload,
  required List<int> samples,
  required int? bytesPerIteration,
}) {
  final statistics = _SampleStatistics(samples);
  final throughput = bytesPerIteration == null
      ? null
      : bytesPerIteration /
            (1024 * 1024) /
            (statistics.mean / Duration.microsecondsPerSecond);
  return BenchmarkWorkloadResult(
    id: workload.id,
    label: workload.label,
    metrics: [
      if (throughput != null)
        BenchmarkMetric(
          id: 'throughput',
          label: 'throughput',
          value: throughput,
          unit: .mebibytesPerSecond,
          direction: .higherIsBetter,
        ),
      _timingMetric('mean', statistics.mean),
      _timingMetric('standard_deviation', statistics.standardDeviation),
      _timingMetric('p50', statistics.p50),
      _timingMetric('p95', statistics.p95),
      _timingMetric('p99', statistics.p99),
    ],
    details: {
      'samples': samples.length,
      'samples_microseconds': List<int>.unmodifiable(samples),
      'bytes_per_iteration': ?bytesPerIteration,
    },
  );
}

void _writeChunks(TerminalController controller, List<Uint8List> chunks) {
  for (var index = 0; index < chunks.length; index++) {
    controller.write(chunks[index]);
  }
}

final class _SampleStatistics {
  final double mean;
  final double standardDeviation;
  final int p50;
  final int p95;
  final int p99;

  factory _SampleStatistics(List<int> samples) {
    final sorted = [...samples]..sort();
    final mean =
        samples.fold<int>(0, (sum, sample) => sum + sample) / samples.length;
    final squaredDifferenceSum = samples.fold<double>(0, (sum, sample) {
      final difference = sample - mean;
      return sum + difference * difference;
    });

    int percentile(double value) => sorted[(sorted.length * value).ceil() - 1];

    return _SampleStatistics._(
      mean: mean,
      standardDeviation: samples.length == 1
          ? 0
          : sqrt(squaredDifferenceSum / (samples.length - 1)),
      p50: percentile(0.50),
      p95: percentile(0.95),
      p99: percentile(0.99),
    );
  }

  const _SampleStatistics._({
    required this.mean,
    required this.standardDeviation,
    required this.p50,
    required this.p95,
    required this.p99,
  });
}

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/benchmarks/input_benchmark.dart' show measureBenchmark;
import '../../../tool/benchmarks/report/model.dart'
    show BenchmarkMetric, BenchmarkWorkloadResult;

void main() {
  group('measureBenchmark', () {
    BenchmarkWorkloadResult measure(List<int> samples) {
      final clock = _FakeClock(samples);
      return measureBenchmark(
        workload: .streamingOutput,
        warmupIterations: 0,
        minimumSamples: samples.length,
        minimumDuration: .zero,
        clock: clock.read,
        step: clock.step,
      );
    }

    BenchmarkMetric metric(BenchmarkWorkloadResult result, String id) {
      return result.metrics.singleWhere((metric) => metric.id == id);
    }

    group('statistics', () {
      test('computes timing distribution statistics', () {
        final result = measure([1000, 2000, 3000, 4000]);

        expect(metric(result, 'mean').value, 2.5);
        expect(
          metric(result, 'standard_deviation').value,
          closeTo(1.291, 0.001),
        );
        expect(
          (
            p50: metric(result, 'p50').value,
            p95: metric(result, 'p95').value,
            p99: metric(result, 'p99').value,
          ),
          (p50: 2.0, p95: 4.0, p99: 4.0),
        );
      });

      test('computes aggregate throughput', () {
        final clock = _FakeClock([2000, 3000]);

        final result = measureBenchmark(
          workload: .streamingOutput,
          warmupIterations: 0,
          minimumSamples: 2,
          minimumDuration: .zero,
          bytesPerIteration: 1024 * 1024,
          clock: clock.read,
          step: clock.step,
        );

        expect(metric(result, 'throughput').value, 400);
      });
    });

    group('sampling', () {
      test('preserves raw samples as diagnostic details', () {
        final result = measure([2000, 3000]);

        expect(result.details['samples_microseconds'], [2000, 3000]);
      });

      test('excludes preparation from measured samples', () {
        final clock = _FakeClock([10, 10]);

        final result = measureBenchmark(
          workload: .streamingOutput,
          warmupIterations: 0,
          minimumSamples: 2,
          minimumDuration: .zero,
          clock: clock.read,
          prepare: () => clock.advance(100),
          step: clock.step,
        );

        expect(result.details['samples_microseconds'], [10, 10]);
      });

      test('runs unmeasured warmup iterations', () {
        final clock = _FakeClock([10]);
        var steps = 0;

        measureBenchmark(
          workload: .streamingOutput,
          warmupIterations: 2,
          minimumSamples: 1,
          minimumDuration: .zero,
          clock: clock.read,
          step: () {
            steps++;
            clock.step();
          },
        );

        expect(steps, 3);
      });

      test('meets the minimum measured duration', () {
        final clock = _FakeClock([10, 10, 10]);

        final result = measureBenchmark(
          workload: .streamingOutput,
          warmupIterations: 0,
          minimumSamples: 1,
          minimumDuration: const Duration(microseconds: 25),
          clock: clock.read,
          step: clock.step,
        );

        expect(result.details['samples_microseconds'], [10, 10, 10]);
      });
    });

    group('workload', () {
      test('rejects a frame workload', () {
        final clock = _FakeClock([10]);

        expect(
          () => measureBenchmark(
            workload: .cleanFrame,
            warmupIterations: 0,
            minimumSamples: 1,
            minimumDuration: .zero,
            clock: clock.read,
            step: clock.step,
          ),
          throwsA(
            isA<ArgumentError>().having(
              (error) => error.message,
              'message',
              contains('input workload'),
            ),
          ),
        );
      });
    });
  });
}

final class _FakeClock {
  final List<int> samples;
  var _microseconds = 0;
  var _sample = 0;

  _FakeClock(this.samples);

  int read() => _microseconds;

  void step() {
    advance(samples[_sample]);
    _sample = (_sample + 1) % samples.length;
  }

  void advance(int microseconds) {
    _microseconds += microseconds;
  }
}

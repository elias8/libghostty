import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter_test/flutter_test.dart';

import '../../../../tool/benchmarks/frame/result.dart'
    show framePerformanceResult;
import '../../../../tool/benchmarks/report/markdown.dart'
    show formatBenchmarkReport;
import '../../../../tool/benchmarks/report/model.dart'
    show
        BenchmarkEnvironment,
        BenchmarkMetric,
        BenchmarkReport,
        BenchmarkWorkloadResult;

void main() {
  group('benchmark reporting', () {
    List<BenchmarkMetric> inputMetrics({required double value}) {
      return [
        BenchmarkMetric(
          id: 'throughput',
          label: 'throughput',
          value: value,
          unit: .mebibytesPerSecond,
          direction: .higherIsBetter,
        ),
        for (final id in const [
          'mean',
          'standard_deviation',
          'p50',
          'p95',
          'p99',
        ])
          BenchmarkMetric(
            id: id,
            label: id,
            value: id == 'standard_deviation' ? 0.25 : 1,
            unit: .milliseconds,
            direction: .lowerIsBetter,
          ),
      ];
    }

    BenchmarkReport report({double value = 100, bool completeMetrics = true}) {
      final metrics = inputMetrics(value: value);
      return BenchmarkReport(
        protocolVersion: 1,
        fixtureDigest: 'sha256:one',
        revision: 'abc123',
        environment: const BenchmarkEnvironment(
          operatingSystem: 'macos',
          operatingSystemVersion: '15.5',
          architecture: 'arm64',
          dartVersion: '3.12.0',
          flutterVersion: '3.44.0',
          runnerImage: 'macos-15',
        ),
        workloads: [
          BenchmarkWorkloadResult(
            id: 'input.streaming_output',
            label: 'streaming output',
            metrics: completeMetrics ? metrics : metrics.take(1).toList(),
            details: const {'samples': 100},
          ),
        ],
      );
    }

    BenchmarkReport frameReport() {
      return BenchmarkReport(
        protocolVersion: 1,
        fixtureDigest: 'sha256:one',
        revision: 'abc123',
        environment: const BenchmarkEnvironment(
          operatingSystem: 'macos',
          operatingSystemVersion: '15.5',
          architecture: 'arm64',
          dartVersion: '3.12.0',
          flutterVersion: '3.44.0',
          runnerImage: 'macos-15',
        ),
        workloads: [
          framePerformanceResult(
            workload: .fullOutput,
            summary: const {
              'average_frame_build_time_millis': 1,
              '90th_percentile_frame_build_time_millis': 2,
              '99th_percentile_frame_build_time_millis': 3,
              'worst_frame_build_time_millis': 4,
              'missed_frame_build_budget_count': 1,
              'average_frame_rasterizer_time_millis': 2,
              '90th_percentile_frame_rasterizer_time_millis': 3,
              '99th_percentile_frame_rasterizer_time_millis': 4,
              'worst_frame_rasterizer_time_millis': 5,
              'missed_frame_rasterizer_budget_count': 2,
              'frame_count': 100,
            },
          ),
        ],
      );
    }

    group('BenchmarkWorkloadResult.fromJson', () {
      test('round trips every workload field', () {
        final workload = report().workloads.single;

        final result = BenchmarkWorkloadResult.fromJson(
          jsonDecode(jsonEncode(workload.toJson())) as Map<String, Object?>,
        );

        expect(result.toJson(), workload.toJson());
      });

      test('rejects a metric with an unknown unit', () {
        final json = report().workloads.single.toJson();
        final metrics = json['metrics']! as List<Object?>;
        final metric = metrics.first! as Map<String, Object?>;
        metric['unit'] = 'frames_per_fortnight';

        expect(
          () => BenchmarkWorkloadResult.fromJson(json),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              contains('frames_per_fortnight'),
            ),
          ),
        );
      });

      test('reports invalid metric values as malformed data', () {
        final json = report().workloads.single.toJson();
        final metrics = json['metrics']! as List<Object?>;
        final metric = metrics.first! as Map<String, Object?>;
        metric['value'] = -1;

        expect(
          () => BenchmarkWorkloadResult.fromJson(json),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              contains('finite and non-negative'),
            ),
          ),
        );
      });
    });

    group('model validation', () {
      test('rejects duplicate result identities', () {
        final original = report();
        final workload = original.workloads.single;
        final metric = inputMetrics(value: 100).first;

        expect(
          () => BenchmarkReport(
            protocolVersion: original.protocolVersion,
            fixtureDigest: original.fixtureDigest,
            revision: original.revision,
            environment: original.environment,
            workloads: [workload, workload],
          ),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              contains('duplicate workload id'),
            ),
          ),
        );
        expect(
          () => BenchmarkWorkloadResult(
            id: 'input.streaming_output',
            label: 'streaming output',
            metrics: [metric, metric],
          ),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              contains('duplicate metric id'),
            ),
          ),
        );
      });

      test('rejects an empty workload identifier', () {
        expect(
          () => BenchmarkWorkloadResult(
            id: ' ',
            label: 'streaming output',
            metrics: inputMetrics(value: 100),
          ),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              contains('workload id must not be empty'),
            ),
          ),
        );
      });

      test('rejects invalid metric values', () {
        final invalidMeasurement = throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('finite and non-negative'),
          ),
        );

        expect(
          () => BenchmarkMetric(
            id: 'throughput',
            label: 'throughput',
            value: -1,
            unit: .mebibytesPerSecond,
            direction: .higherIsBetter,
          ),
          invalidMeasurement,
        );
        expect(
          () => BenchmarkMetric(
            id: 'throughput',
            label: 'throughput',
            value: double.nan,
            unit: .mebibytesPerSecond,
            direction: .higherIsBetter,
          ),
          invalidMeasurement,
        );
      });

      test('rejects a missing required metric', () {
        final workload = BenchmarkWorkloadResult(
          id: 'input.streaming_output',
          label: 'streaming output',
          metrics: inputMetrics(value: 100).take(1).toList(),
        );

        expect(
          () => workload.metric('mean'),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              contains('missing metric "mean"'),
            ),
          ),
        );
      });

      test('rejects a non-integer count detail', () {
        final workload = BenchmarkWorkloadResult(
          id: 'input.streaming_output',
          label: 'streaming output',
          metrics: inputMetrics(value: 100),
          details: const {'samples': 1.5},
        );

        expect(
          () => workload.detailCount('samples'),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              contains('count detail "samples"'),
            ),
          ),
        );
      });
    });

    group('formatBenchmarkReport', () {
      test('formats an input benchmark report', () {
        final benchmarkReport = report(value: 120.25);

        final result = formatBenchmarkReport(benchmarkReport);

        expect(
          result,
          contains(
            '| streaming output | 120.25 MiB/s | 1.00 ms ± 0.25 ms | '
            '1.00 ms | 1.00 ms | 1.00 ms | 100 |',
          ),
        );
        expect(result, contains('Runner: macos-15'));
      });

      test('formats frame misses as a count and rate', () {
        final benchmarkReport = frameReport();

        final result = formatBenchmarkReport(benchmarkReport);

        expect(result, contains('| 2/100 (2.0%) | 100 |'));
      });

      test('rejects an incomplete input workload', () {
        final benchmarkReport = report(completeMetrics: false);

        expect(
          () => formatBenchmarkReport(benchmarkReport),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              contains('missing metric "mean"'),
            ),
          ),
        );
      });
    });
  });
}

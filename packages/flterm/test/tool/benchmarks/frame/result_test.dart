import 'package:flutter_test/flutter_test.dart';

import '../../../../tool/benchmarks/frame/result.dart'
    show framePerformanceResult;

void main() {
  group('framePerformanceResult', () {
    Map<String, Object?> summary({
      List<int> buildTimes = const [500, 800, 1200],
      List<int> rasterTimes = const [700, 1000, 1500],
    }) => {
      'average_frame_build_time_millis': 0.5,
      '90th_percentile_frame_build_time_millis': 0.8,
      '99th_percentile_frame_build_time_millis': 1.2,
      'worst_frame_build_time_millis': 2.0,
      'missed_frame_build_budget_count': 1,
      'average_frame_rasterizer_time_millis': 0.7,
      '90th_percentile_frame_rasterizer_time_millis': 1.0,
      '99th_percentile_frame_rasterizer_time_millis': 1.5,
      'worst_frame_rasterizer_time_millis': 2.5,
      'missed_frame_rasterizer_budget_count': 2,
      'frame_count': 300,
      'frame_build_times': buildTimes,
      'frame_rasterizer_times': rasterTimes,
    };

    group('conversion', () {
      test('preserves the Flutter frame summary', () {
        final result = framePerformanceResult(
          workload: .fullOutput,
          summary: summary(),
        );

        expect(result.metric('ui_p99').value, 1.2);
        expect(result.metric('raster_p99').value, 1.5);
        expect(result.metric('raster_missed_budget').value, 2);
        expect(result.details['frame_build_times'], [500, 800, 1200]);
      });
    });

    group('validation', () {
      test('rejects a summary without required metrics', () {
        expect(
          () =>
              framePerformanceResult(workload: .fullOutput, summary: const {}),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              contains('average_frame_build_time_millis'),
            ),
          ),
        );
      });

      test('rejects an input workload', () {
        expect(
          () => framePerformanceResult(
            workload: .streamingOutput,
            summary: summary(),
          ),
          throwsA(
            isA<ArgumentError>().having(
              (error) => error.message,
              'message',
              contains('frame workload'),
            ),
          ),
        );
      });
    });
  });
}

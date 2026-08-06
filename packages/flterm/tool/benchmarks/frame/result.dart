import '../protocol.dart';
import '../report/model.dart';

enum _FrameMetric {
  /// Mean framework build duration.
  uiAverage(
    'ui_average',
    'UI average',
    'average_frame_build_time_millis',
    .milliseconds,
  ),

  /// 90th-percentile framework build duration.
  uiP90(
    'ui_p90',
    'UI p90',
    '90th_percentile_frame_build_time_millis',
    .milliseconds,
  ),

  /// 99th-percentile framework build duration.
  uiP99(
    'ui_p99',
    'UI p99',
    '99th_percentile_frame_build_time_millis',
    .milliseconds,
  ),

  /// Longest framework build duration.
  uiWorst(
    'ui_worst',
    'UI worst',
    'worst_frame_build_time_millis',
    .milliseconds,
  ),

  /// Framework builds exceeding Flutter's frame budget.
  uiMissedBudget(
    'ui_missed_budget',
    'UI missed 16 ms budget',
    'missed_frame_build_budget_count',
    .count,
  ),

  /// Mean engine raster duration.
  rasterAverage(
    'raster_average',
    'raster average',
    'average_frame_rasterizer_time_millis',
    .milliseconds,
  ),

  /// 90th-percentile engine raster duration.
  rasterP90(
    'raster_p90',
    'raster p90',
    '90th_percentile_frame_rasterizer_time_millis',
    .milliseconds,
  ),

  /// 99th-percentile engine raster duration.
  rasterP99(
    'raster_p99',
    'raster p99',
    '99th_percentile_frame_rasterizer_time_millis',
    .milliseconds,
  ),

  /// Longest engine raster duration.
  rasterWorst(
    'raster_worst',
    'raster worst',
    'worst_frame_rasterizer_time_millis',
    .milliseconds,
  ),

  /// Raster passes exceeding Flutter's frame budget.
  rasterMissedBudget(
    'raster_missed_budget',
    'raster missed 16 ms budget',
    'missed_frame_rasterizer_budget_count',
    .count,
  );

  const _FrameMetric(this.id, this.label, this.source, this.unit);

  final String id;
  final String label;
  final String source;
  final BenchmarkMetricUnit unit;
}

/// Converts Flutter's frame summary into stable benchmark metrics.
BenchmarkWorkloadResult framePerformanceResult({
  required BenchmarkWorkload workload,
  required Map<String, Object?> summary,
}) {
  if (workload.kind != .frame) {
    throw ArgumentError.value(workload, 'workload', 'must be a frame workload');
  }
  return BenchmarkWorkloadResult(
    id: workload.id,
    label: workload.label,
    metrics: [
      for (final metric in _FrameMetric.values)
        BenchmarkMetric(
          id: metric.id,
          label: metric.label,
          value: _metric(summary, metric.source).toDouble(),
          unit: metric.unit,
          direction: .lowerIsBetter,
        ),
    ],
    details: Map.unmodifiable(summary),
  );
}

num _metric(Map<String, Object?> summary, String name) {
  return switch (summary[name]) {
    final num value => value,
    _ => throw FormatException('Frame summary metric "$name" is missing.'),
  };
}

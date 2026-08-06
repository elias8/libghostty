import '../protocol.dart';
import 'model.dart';

enum _FramePhase {
  /// Framework build work recorded on Flutter's UI thread.
  ui('UI', 'ui'),

  /// Engine raster work recorded after the UI phase.
  raster('raster', 'raster');

  const _FramePhase(this.label, this.metricPrefix);

  final String label;
  final String metricPrefix;
}

String formatBenchmarkReport(BenchmarkReport report) {
  final environment = report.environment;
  final input = _workloads(report, .input);
  final frames = _workloads(report, .frame);
  final platform = [
    'Platform: ${environment.operatingSystem}',
    environment.operatingSystemVersion,
    '(${environment.architecture})  ',
  ].join(' ');
  final runner = environment.runnerImage;
  final frameHeader = [
    '| workload | phase | average | p90 | p99 | worst |',
    'missed >16 ms | frames |',
  ].join(' ');
  final directionNote = [
    'Throughput is higher-is-better.',
    'Frame timings and missed budgets are lower-is-better.',
    'Missed budgets are shown as count over captured frames and rate.',
  ].join(' ');

  return [
    '# flterm benchmark',
    '',
    'Revision: `${report.revision}`  ',
    platform,
    if (runner != null) 'Runner: $runner  ',
    'Flutter: ${environment.flutterVersion}  ',
    'Dart: ${environment.dartVersion}  ',
    'Mode: profile  ',
    'Terminal: $benchmarkColumns×$benchmarkRows at device pixel ratio 1  ',
    'Protocol: ${report.protocolVersion}  ',
    'Fixture: `${report.fixtureDigest}`',
    '',
    '## Input throughput',
    '',
    '| workload | throughput | mean ± std dev | p50 | p95 | p99 | samples |',
    '|---|---:|---:|---:|---:|---:|---:|',
    for (final workload in input) _inputRow(workload),
    '',
    '## Frame performance',
    '',
    frameHeader,
    '|---|---|---:|---:|---:|---:|---:|---:|',
    for (final workload in frames) ...[
      for (final phase in _FramePhase.values) _frameRow(workload, phase),
    ],
    '',
    directionNote,
  ].join('\n');
}

String _inputRow(BenchmarkWorkloadResult workload) {
  final mean = _metricValue(workload, 'mean');
  final deviation = _metricValue(workload, 'standard_deviation');
  final values = [
    workload.label,
    _metricValue(workload, 'throughput'),
    '$mean ± $deviation',
    _metricValue(workload, 'p50'),
    _metricValue(workload, 'p95'),
    _metricValue(workload, 'p99'),
    '${workload.detailCount('samples')}',
  ];
  return '| ${values.join(' | ')} |';
}

String _frameRow(BenchmarkWorkloadResult workload, _FramePhase phase) {
  final prefix = phase.metricPrefix;
  final values = [
    workload.label,
    phase.label,
    _metricValue(workload, '${prefix}_average'),
    _metricValue(workload, '${prefix}_p90'),
    _metricValue(workload, '${prefix}_p99'),
    _metricValue(workload, '${prefix}_worst'),
    _missedFrames(workload, '${prefix}_missed_budget'),
    '${workload.detailCount('frame_count')}',
  ];
  return '| ${values.join(' | ')} |';
}

String _metricValue(BenchmarkWorkloadResult workload, String id) {
  return _value(workload.metric(id));
}

String _value(BenchmarkMetric metric) {
  final digits = metric.unit == .count ? 0 : 2;
  final suffix = metric.unit.displayName;
  final value = metric.value.toStringAsFixed(digits);
  return suffix.isEmpty ? value : '$value $suffix';
}

String _missedFrames(BenchmarkWorkloadResult workload, String metricId) {
  final frames = workload.detailCount('frame_count');
  if (frames == 0) {
    throw FormatException(
      'Benchmark workload "${workload.id}" contains no frame timings.',
    );
  }
  final missed = workload.metric(metricId).value;
  if (missed != missed.roundToDouble()) {
    throw FormatException(
      'Benchmark workload "${workload.id}" has a fractional missed count.',
    );
  }
  final count = missed.toInt();
  final rate = count / frames * 100;
  return '$count/$frames (${rate.toStringAsFixed(1)}%)';
}

Iterable<BenchmarkWorkloadResult> _workloads(
  BenchmarkReport report,
  BenchmarkWorkloadKind kind,
) {
  return report.workloads.where(
    (result) => BenchmarkWorkload.fromId(result.id).kind == kind,
  );
}

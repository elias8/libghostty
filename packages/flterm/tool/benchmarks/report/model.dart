const benchmarkReportSchemaVersion = 1;

/// Runtime properties recorded with a benchmark result.
final class BenchmarkEnvironment {
  final String operatingSystem;
  final String operatingSystemVersion;
  final String architecture;
  final String dartVersion;
  final String flutterVersion;
  final String? runnerImage;

  const BenchmarkEnvironment({
    required this.operatingSystem,
    required this.operatingSystemVersion,
    required this.architecture,
    required this.dartVersion,
    required this.flutterVersion,
    this.runnerImage,
  });

  Map<String, Object?> toJson() => {
    'operating_system': operatingSystem,
    'operating_system_version': operatingSystemVersion,
    'architecture': architecture,
    'dart_version': dartVersion,
    'flutter_version': flutterVersion,
    ...switch (runnerImage) {
      final value? => {'runner_image': value},
      null => const {},
    },
  };
}

/// One measurement produced by a benchmark workload.
final class BenchmarkMetric {
  final String id;
  final String label;
  final double value;
  final BenchmarkMetricUnit unit;
  final BenchmarkMetricDirection direction;

  BenchmarkMetric({
    required String id,
    required String label,
    required double value,
    required this.unit,
    required this.direction,
  }) : id = _requiredText(id, 'metric id'),
       label = _requiredText(label, 'metric label'),
       value = _measurement(value);

  factory BenchmarkMetric.fromJson(Map<String, Object?> json) {
    return BenchmarkMetric(
      id: json['id']! as String,
      label: json['label']! as String,
      value: (json['value']! as num).toDouble(),
      unit: switch (json['unit']! as String) {
        'milliseconds' => .milliseconds,
        'mebibytes_per_second' => .mebibytesPerSecond,
        'count' => .count,
        final value => throw FormatException(
          'Unknown benchmark metric unit "$value".',
        ),
      },
      direction: switch (json['direction']! as String) {
        'higher_is_better' => .higherIsBetter,
        'lower_is_better' => .lowerIsBetter,
        final value => throw FormatException(
          'Unknown benchmark metric direction "$value".',
        ),
      },
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'value': value,
    'unit': unit.jsonName,
    'direction': direction.jsonName,
  };
}

enum BenchmarkMetricDirection {
  higherIsBetter('higher_is_better'),
  lowerIsBetter('lower_is_better');

  const BenchmarkMetricDirection(this.jsonName);

  final String jsonName;
}

enum BenchmarkMetricUnit {
  milliseconds('milliseconds', 'ms'),
  mebibytesPerSecond('mebibytes_per_second', 'MiB/s'),
  count('count', '');

  const BenchmarkMetricUnit(this.jsonName, this.displayName);

  final String jsonName;
  final String displayName;
}

/// Versioned output from one benchmark run.
final class BenchmarkReport {
  final int schemaVersion = benchmarkReportSchemaVersion;
  final int protocolVersion;
  final String fixtureDigest;
  final String revision;
  final BenchmarkEnvironment environment;
  final List<BenchmarkWorkloadResult> workloads;

  BenchmarkReport({
    required this.protocolVersion,
    required this.fixtureDigest,
    required this.revision,
    required this.environment,
    required List<BenchmarkWorkloadResult> workloads,
  }) : workloads = _uniqueWorkloads(workloads);

  Map<String, Object?> toJson() => {
    'schema_version': schemaVersion,
    'protocol_version': protocolVersion,
    'fixture_digest': fixtureDigest,
    'revision': revision,
    'environment': environment.toJson(),
    'workloads': [for (final workload in workloads) workload.toJson()],
  };
}

/// Results and diagnostic details for one stable workload identity.
final class BenchmarkWorkloadResult {
  final String id;
  final String label;
  final List<BenchmarkMetric> metrics;
  final Map<String, Object?> details;

  BenchmarkWorkloadResult({
    required String id,
    required String label,
    required List<BenchmarkMetric> metrics,
    Map<String, Object?> details = const {},
  }) : id = _requiredText(id, 'workload id'),
       label = _requiredText(label, 'workload label'),
       metrics = _uniqueMetrics(metrics),
       details = Map.unmodifiable(details);

  factory BenchmarkWorkloadResult.fromJson(Map<String, Object?> json) {
    return BenchmarkWorkloadResult(
      id: json['id']! as String,
      label: json['label']! as String,
      metrics: [
        for (final value in json['metrics']! as List<Object?>)
          BenchmarkMetric.fromJson(value! as Map<String, Object?>),
      ],
      details: json['details']! as Map<String, Object?>,
    );
  }

  /// Returns the required non-negative integer detail identified by [id].
  int detailCount(String id) {
    return switch (details[id]) {
      final int value when value >= 0 => value,
      _ => throw FormatException(
        'Benchmark workload "${this.id}" is missing count detail "$id".',
      ),
    };
  }

  /// Returns the required metric identified by [id].
  BenchmarkMetric metric(String id) {
    for (final metric in metrics) {
      if (metric.id == id) return metric;
    }
    throw FormatException(
      'Benchmark workload "${this.id}" is missing metric "$id".',
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'metrics': [for (final metric in metrics) metric.toJson()],
    'details': details,
  };
}

double _measurement(double value) {
  if (!value.isFinite || value < 0) {
    throw const FormatException(
      'Benchmark metric "value" must be finite and non-negative.',
    );
  }
  return value;
}

String _requiredText(String value, String name) {
  if (value.trim().isEmpty) {
    throw FormatException('Benchmark $name must not be empty.');
  }
  return value;
}

List<BenchmarkMetric> _uniqueMetrics(List<BenchmarkMetric> metrics) {
  final ids = <String>{};
  for (final metric in metrics) {
    if (!ids.add(metric.id)) {
      throw FormatException(
        'Benchmark workload contains duplicate metric id "${metric.id}".',
      );
    }
  }
  return List.unmodifiable(metrics);
}

List<BenchmarkWorkloadResult> _uniqueWorkloads(
  List<BenchmarkWorkloadResult> workloads,
) {
  final ids = <String>{};
  for (final workload in workloads) {
    if (!ids.add(workload.id)) {
      throw FormatException(
        'Benchmark report contains duplicate workload id "${workload.id}".',
      );
    }
  }
  return List.unmodifiable(workloads);
}

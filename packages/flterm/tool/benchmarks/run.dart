import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';

import 'fixture/terminal.dart';
import 'protocol.dart';
import 'report/markdown.dart';
import 'report/model.dart';

const _usageExitCode = 64;

/// Flutter drive arguments for the profile benchmark.
const benchmarkDriveArguments = [
  'drive',
  '--no-dds',
  '--driver',
  'test_driver/flterm_benchmark_driver.dart',
  '--target',
  'integration_test/flterm_benchmark.dart',
  '--profile',
  '--dart-define=INTEGRATION_TEST_SHOULD_REPORT_RESULTS_TO_NATIVE=false',
  '-d',
  'macos',
];

Future<void> main(List<String> arguments) async {
  if (!Platform.isMacOS) {
    stderr.writeln(
      'The flterm example currently provides only a macOS desktop runner.',
    );
    exitCode = _usageExitCode;
    return;
  }

  late final ({Directory? outputDirectory, String revision}) options;
  try {
    options = _parseOptions(arguments);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exitCode = _usageExitCode;
    return;
  }

  try {
    await _BenchmarkRun(options).execute();
  } on ProcessException catch (error) {
    stderr.writeln(error);
    exitCode = error.errorCode;
  } on FileSystemException catch (error) {
    stderr.writeln(error.message);
    exitCode = 1;
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exitCode = 1;
  }
}

final class _BenchmarkRun {
  final String revision;
  final Directory exampleDirectory;
  final BenchmarkArtifacts artifacts;

  factory _BenchmarkRun(
    ({Directory? outputDirectory, String revision}) options,
  ) {
    final packageDirectory = File.fromUri(Platform.script).parent.parent.parent;
    final exampleDirectory = Directory.fromUri(
      packageDirectory.uri.resolve('example/'),
    );
    return _BenchmarkRun._(
      revision: options.revision,
      exampleDirectory: exampleDirectory,
      artifacts: BenchmarkArtifacts(
        options.outputDirectory ??
            Directory.fromUri(
              exampleDirectory.uri.resolve('build/benchmark-results/'),
            ),
      ),
    );
  }

  const _BenchmarkRun._({
    required this.revision,
    required this.exampleDirectory,
    required this.artifacts,
  });

  Future<void> execute() async {
    artifacts.prepare();
    final rawFlutter = File.fromUri(
      exampleDirectory.uri.resolve('build/flterm_benchmarks.json'),
    );
    if (rawFlutter.existsSync()) rawFlutter.deleteSync();

    final flutterVersion = await _flutterVersion();
    final processExitCode = await _runFlutter();
    if (processExitCode != 0) {
      exitCode = processExitCode;
      return;
    }

    final report = benchmarkReportFromFlutterResponse(
      _readJsonObject(rawFlutter),
      revision: revision,
      environment: _environment(flutterVersion),
    );
    final markdown = formatBenchmarkReport(report);
    artifacts.writeResults(
      report: report,
      markdown: markdown,
      rawFlutter: rawFlutter,
    );
    stdout.writeln(markdown);
  }

  Future<String> _flutterVersion() async {
    final result = await Process.run('flutter', const [
      '--version',
      '--machine',
    ]);
    if (result.exitCode != 0) {
      throw ProcessException(
        'flutter',
        const ['--version', '--machine'],
        result.stderr as String,
        result.exitCode,
      );
    }
    final Object? json = jsonDecode(result.stdout as String);
    final data = _jsonObject(json, 'Flutter version');
    return switch (data['frameworkVersion']) {
      final String value when value.isNotEmpty => value,
      _ => throw const FormatException(
        'Flutter version output contains no framework version.',
      ),
    };
  }

  Future<int> _runFlutter() async {
    final process = await Process.start(
      'flutter',
      benchmarkDriveArguments,
      workingDirectory: exampleDirectory.path,
    );
    final output = _pipe(process.stdout, artifacts.stdoutLog, stdout);
    final errors = _pipe(process.stderr, artifacts.stderrLog, stderr);
    final (processExitCode, _, _) = await (
      process.exitCode,
      output,
      errors,
    ).wait;
    return processExitCode;
  }

  Future<void> _pipe(
    Stream<List<int>> input,
    File logFile,
    IOSink console,
  ) async {
    final log = logFile.openWrite();
    try {
      await for (final text in input.transform(utf8.decoder)) {
        log.write(text);
        console.write(text);
      }
    } finally {
      await log.close();
    }
  }

  BenchmarkEnvironment _environment(String flutterVersion) {
    final runnerImage = [
      ?Platform.environment['ImageOS'],
      ?Platform.environment['ImageVersion'],
    ].join(' ');
    return BenchmarkEnvironment(
      operatingSystem: Platform.operatingSystem,
      operatingSystemVersion: Platform.operatingSystemVersion,
      architecture: Abi.current().toString(),
      dartVersion: Platform.version.split(' ').first,
      flutterVersion: flutterVersion,
      runnerImage: runnerImage.isEmpty ? null : runnerImage,
    );
  }
}

/// Validates Flutter's response and attaches host-side run metadata.
BenchmarkReport benchmarkReportFromFlutterResponse(
  Map<String, Object?> response, {
  required String revision,
  required BenchmarkEnvironment environment,
}) {
  final workloadData = switch (response['workloads']) {
    final List<Object?> values => values,
    _ => throw const FormatException(
      'Flutter benchmark response contains no workloads.',
    ),
  };
  final fontDigest = switch (response['font_digest']) {
    final String value when value.isNotEmpty => value,
    _ => throw const FormatException(
      'Flutter benchmark response contains no font digest.',
    ),
  };
  final report = BenchmarkReport(
    protocolVersion: benchmarkProtocolVersion,
    fixtureDigest: TerminalBenchmarkFixture.benchmarkDigest(fontDigest),
    revision: revision,
    environment: environment,
    workloads: [
      for (final value in workloadData)
        BenchmarkWorkloadResult.fromJson(_jsonObject(value, 'workload')),
    ],
  );
  final expected = {
    for (final workload in BenchmarkWorkload.values) workload.id,
  };
  final actual = {for (final workload in report.workloads) workload.id};
  if (report.workloads.length != expected.length ||
      !actual.containsAll(expected)) {
    throw const FormatException(
      'Flutter benchmark response must contain every protocol workload.',
    );
  }
  return report;
}

Map<String, Object?> _readJsonObject(File file) {
  if (!file.existsSync()) {
    throw FormatException('Benchmark response file is missing: ${file.path}');
  }
  final Object? json = jsonDecode(file.readAsStringSync());
  return _jsonObject(json, 'benchmark response');
}

Map<String, Object?> _jsonObject(Object? value, String name) {
  return switch (value) {
    final Map<Object?, Object?> value => Map<String, Object?>.from(value),
    _ => throw FormatException('$name must be a JSON object.'),
  };
}

/// Owns the files produced by one host-side benchmark run.
///
/// [prepare] removes only known benchmark artifacts, leaving other entries in
/// the output directory intact.
///
/// ```dart
/// final artifacts = BenchmarkArtifacts(Directory('/tmp/flterm-results'));
/// artifacts.prepare();
/// ```
final class BenchmarkArtifacts {
  static const _names = [
    'results.json',
    'report.md',
    'raw-flutter.json',
    'flutter.stdout.log',
    'flutter.stderr.log',
  ];

  final Directory directory;

  const BenchmarkArtifacts(this.directory);

  File get stdoutLog => _file('flutter.stdout.log');
  File get stderrLog => _file('flutter.stderr.log');

  void prepare() {
    directory.createSync(recursive: true);
    for (final name in _names) {
      final artifact = _file(name);
      if (artifact.existsSync()) artifact.deleteSync();
    }
  }

  void writeResults({
    required BenchmarkReport report,
    required String markdown,
    required File rawFlutter,
  }) {
    _writeText(
      'results.json',
      const JsonEncoder.withIndent('  ').convert(report.toJson()),
    );
    _writeText('report.md', markdown);
    rawFlutter.copySync(_file('raw-flutter.json').path);
  }

  File _file(String name) => File.fromUri(directory.uri.resolve(name));

  void _writeText(String name, String contents) {
    _file(name).writeAsStringSync('$contents\n');
  }
}

({Directory? outputDirectory, String revision}) _parseOptions(
  List<String> arguments,
) {
  Directory? output;
  var revision = 'working-tree';
  for (var index = 0; index < arguments.length; index += 2) {
    if (index + 1 >= arguments.length) {
      throw FormatException('Missing value for ${arguments[index]}.');
    }
    final value = arguments[index + 1];
    switch (arguments[index]) {
      case '--output':
        output = Directory(value);
      case '--revision':
        revision = value;
      default:
        throw FormatException('Unknown option ${arguments[index]}.');
    }
  }
  return (outputDirectory: output, revision: revision);
}

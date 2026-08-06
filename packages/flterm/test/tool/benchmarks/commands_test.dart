import 'dart:io' show Directory, File;

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/benchmarks/protocol.dart' show BenchmarkWorkload;
import '../../../tool/benchmarks/report/model.dart'
    show BenchmarkEnvironment, BenchmarkWorkloadResult;
import '../../../tool/benchmarks/run.dart'
    as run
    show
        BenchmarkArtifacts,
        benchmarkDriveArguments,
        benchmarkReportFromFlutterResponse;

void main() {
  group('benchmark commands', () {
    group('drive arguments', () {
      test('disable DDS for integration performance tracing', () {
        expect(run.benchmarkDriveArguments, contains('--no-dds'));
      });
    });

    group('BenchmarkArtifacts', () {
      group('prepare', () {
        test('removes only artifacts from a prior run', () {
          final directory = Directory.systemTemp.createTempSync(
            'flterm-benchmark-artifacts-',
          );
          addTearDown(() => directory.deleteSync(recursive: true));
          File.fromUri(
            directory.uri.resolve('results.json'),
          ).writeAsStringSync('old results');
          File.fromUri(
            directory.uri.resolve('report.md'),
          ).writeAsStringSync('old report');
          File.fromUri(
            directory.uri.resolve('raw-flutter.json'),
          ).writeAsStringSync('old raw data');
          File.fromUri(
            directory.uri.resolve('flutter.stdout.log'),
          ).writeAsStringSync('old stdout');
          File.fromUri(
            directory.uri.resolve('flutter.stderr.log'),
          ).writeAsStringSync('old stderr');
          final unrelated = File.fromUri(directory.uri.resolve('keep.txt'))
            ..writeAsStringSync('keep');
          final artifacts = run.BenchmarkArtifacts(directory);

          artifacts.prepare();

          expect(
            directory.listSync().map((entry) => entry.uri.pathSegments.last),
            ['keep.txt'],
          );
          expect(unrelated.readAsStringSync(), 'keep');
        });
      });
    });

    group('benchmarkReportFromFlutterResponse', () {
      Map<String, Object?> response() => {
        'font_digest': 'sha256:fonts',
        'workloads': <Object?>[
          for (final workload in BenchmarkWorkload.values)
            BenchmarkWorkloadResult(
              id: workload.id,
              label: workload.label,
              metrics: const [],
            ).toJson(),
        ],
      };

      const environment = BenchmarkEnvironment(
        operatingSystem: 'macos',
        operatingSystemVersion: '15.5',
        architecture: 'arm64',
        dartVersion: '3.12.0',
        flutterVersion: '3.44.0',
      );

      test('creates a report from every workload', () {
        final result = run.benchmarkReportFromFlutterResponse(
          response(),
          revision: 'abc123',
          environment: environment,
        );

        expect(
          result.workloads.map((workload) => workload.id),
          BenchmarkWorkload.values.map((workload) => workload.id),
        );
      });

      test('rejects a missing workload', () {
        final incompleteResponse = response();
        (incompleteResponse['workloads']! as List<Object?>).removeLast();

        expect(
          () => run.benchmarkReportFromFlutterResponse(
            incompleteResponse,
            revision: 'abc123',
            environment: environment,
          ),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              contains('every protocol workload'),
            ),
          ),
        );
      });
    });
  });
}

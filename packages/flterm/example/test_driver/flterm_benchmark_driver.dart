import 'package:integration_test/integration_test_driver.dart';

Future<void> main() {
  return integrationDriver(
    responseDataCallback: (data) {
      if (data == null) {
        throw const FormatException('Benchmark returned no report data.');
      }
      return writeResponseData(data, testOutputFilename: 'flterm_benchmarks');
    },
  );
}

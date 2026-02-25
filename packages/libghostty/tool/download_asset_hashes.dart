// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

/// Downloads asset hashes from the latest successful build on main branch.
void main() async {
  const repo = 'elias8/libghostty';
  final runResult = await Process.run('gh', [
    'run',
    'list',
    '--repo',
    repo,
    '--workflow',
    'build.yml',
    '--branch',
    'main',
    '--status',
    'success',
    '--limit',
    '1',
    '--json',
    'databaseId',
  ]);

  if (runResult.exitCode != 0) {
    print('Error: ${runResult.stderr}');
    exit(1);
  }

  final runs = jsonDecode(runResult.stdout.toString()) as List<Object?>;
  if (runs.isEmpty) {
    print('No successful builds found');
    exit(1);
  }
  final run = runs.first! as Map<String, Object?>;
  final runId = run['databaseId']! as int;
  print('Found run: $runId');

  final tempDir = Directory.systemTemp.createTempSync('ghostty-');
  try {
    await Process.run('gh', [
      'run',
      'download',
      '--repo',
      repo,
      '$runId',
      '--name',
      'asset-hashes',
      '--dir',
      tempDir.path,
    ]);

    final downloaded = File('${tempDir.path}/asset_hashes.dart');
    if (!downloaded.existsSync()) {
      print('asset_hashes.dart not found');
      exit(1);
    }

    final version = RegExp(
      r'^version:\s*(\S+)',
      multiLine: true,
    ).firstMatch(File('pubspec.yaml').readAsStringSync())!.group(1)!;

    var content = downloaded.readAsStringSync();
    content = content.replaceFirst(
      RegExp("const releaseTag = (?:null|'[^']*')"),
      "const releaseTag = 'v$version'",
    );

    File('lib/src/hook/asset_hashes.dart').writeAsStringSync(content);
    print('Updated to v$version');
  } finally {
    tempDir.deleteSync(recursive: true);
  }
}

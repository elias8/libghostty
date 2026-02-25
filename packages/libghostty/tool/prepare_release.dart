// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

void main() async {
  const repo = 'elias8/libghostty';
  final repoRoot = Directory.current.parent.parent.path;

  const assetHashesPath = 'packages/libghostty/lib/src/hook/asset_hashes.dart';
  const pubspecPath = 'packages/libghostty/pubspec.yaml';
  final absAssetHashes = '$repoRoot/$assetHashesPath';
  final absPubspec = '$repoRoot/$pubspecPath';

  // Check file is clean (no staged or unstaged changes)
  final status = await _git([
    '-C',
    repoRoot,
    'status',
    '--porcelain',
    assetHashesPath,
  ]);
  if (status.trim().isNotEmpty) {
    print('Error: $assetHashesPath has uncommitted changes.');
    print('Commit or stash them before running this script.');
    exit(1);
  }

  final runs =
      jsonDecode(
            await _gh([
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
            ]),
          )
          as List;

  if (runs.isEmpty) {
    print('Error: No successful builds found on main branch.');
    exit(1);
  }
  final run = runs.first as Map<String, Object?>;
  final runId = run['databaseId']! as int;
  print('Found build #$runId');

  final tempDir = Directory.systemTemp.createTempSync('ghostty-');
  try {
    await _gh([
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
      print('Error: asset_hashes.dart not found in artifact');
      exit(1);
    }

    final version = RegExp(
      r'^version:\s*(\S+)',
      multiLine: true,
    ).firstMatch(File(absPubspec).readAsStringSync())!.group(1)!;

    final newContent = downloaded.readAsStringSync().replaceFirst(
      RegExp("const releaseTag = (?:null|'[^']*')"),
      "const releaseTag = 'libghostty-v$version'",
    );

    final currentContent = await _git([
      '-C',
      repoRoot,
      'show',
      'HEAD:$assetHashesPath',
    ]);
    if (currentContent.trim() == newContent.trim()) {
      print('Asset hashes already up to date.');
      return;
    }

    File(absAssetHashes).writeAsStringSync(newContent);
    await _git(['-C', repoRoot, 'add', assetHashesPath]);
    await _git([
      '-C',
      repoRoot,
      'commit',
      assetHashesPath,
      '-m',
      'chore: update asset hashes for v$version',
    ]);

    print('Committed: chore: update asset hashes for v$version\n');
    print('Next steps:');
    print('Run: git tag libghostty-v$version');
    print('git push origin main libghostty-v$version');
  } finally {
    tempDir.deleteSync(recursive: true);
  }
}

Future<String> _gh(List<String> args) async {
  final result = await Process.run('gh', args);
  if (result.exitCode != 0) {
    print('Error: ${result.stderr}');
    exit(1);
  }
  return result.stdout.toString();
}

Future<String> _git(List<String> args) async {
  final result = await Process.run('git', args);
  if (result.exitCode != 0) {
    print('Error: ${result.stderr}');
    exit(1);
  }
  return result.stdout.toString();
}

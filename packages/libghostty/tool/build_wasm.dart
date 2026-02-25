import 'dart:io';

import 'package:libghostty/src/hook/ghostty_source.dart';

void main() async {
  final packageRoot = _findPackageRoot();
  final sourceDir = await resolveSource(
    packageRoot: packageRoot.uri,
    cacheBase: packageRoot.uri.resolve('.dart_tool/'),
  );

  stdout.writeln('Compiling libghostty for wasm32-freestanding...');
  _compileWithZig(sourceDir);

  final wasmSource = File('${sourceDir.path}/zig-out/bin/ghostty-vt.wasm');
  if (!wasmSource.existsSync()) {
    throw Exception('WASM binary not found at ${wasmSource.path} after build.');
  }

  final wasmTarget = File('${packageRoot.path}/lib/src/wasm/libghostty.wasm');
  wasmTarget.parent.createSync(recursive: true);
  wasmSource.copySync(wasmTarget.path);

  final size = wasmTarget.lengthSync();
  stdout.writeln(
    'Copied libghostty.wasm to lib/src/wasm/ '
    '(${(size / 1024).toStringAsFixed(1)} KB)',
  );
}

void _compileWithZig(Directory sourceDir) {
  final result = Process.runSync('zig', [
    'build',
    'lib-vt',
    '-Dtarget=wasm32-freestanding',
    '-Doptimize=ReleaseSmall',
  ], workingDirectory: sourceDir.path);

  if (result.exitCode != 0) {
    throw Exception(
      'Zig compilation failed (exit code ${result.exitCode}):\n'
      'stdout: ${result.stdout}\n'
      'stderr: ${result.stderr}',
    );
  }
}

Directory _findPackageRoot() {
  final scriptUri = Platform.script;
  if (scriptUri.scheme == 'file') {
    return Directory(scriptUri.resolve('..').toFilePath());
  }
  return Directory.current;
}

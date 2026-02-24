part of 'library_provider.dart';

/// Compiles the native library from Ghostty source using Zig.
final class CompileFromSource extends LibraryProvider {
  final BuildInput input;

  const CompileFromSource(this.input);

  @override
  Future<void> provide(File target) async {
    final targetOS = input.config.code.targetOS;
    final targetArch = input.config.code.targetArchitecture;
    final iOSSdk = targetOS == OS.iOS ? input.config.code.iOS.targetSdk : null;

    final sourceDir = await resolveSource(
      packageRoot: input.packageRoot,
      cacheBase: input.outputDirectoryShared,
    );

    final installDir = target.parent.parent.uri;
    final zig = zigTarget(targetOS, targetArch, iOSSdk: iOSSdk);

    final zigArgs = [
      'build',
      'lib-vt',
      '-p',
      Directory.fromUri(installDir).path,
      '--release=fast',
      if (zig != null) '-Dtarget=$zig',
      if (iOSSdk == IOSSdk.iPhoneSimulator && targetArch == Architecture.arm64)
        '-Dcpu=apple_a17',
    ];

    final result = Process.runSync(
      'zig',
      zigArgs,
      workingDirectory: sourceDir.path,
    );

    if (result.exitCode != 0) {
      throw Exception(
        'Zig compilation failed (exit code ${result.exitCode}):\n'
        'stdout: ${result.stdout}\n'
        'stderr: ${result.stderr}',
      );
    }
  }
}

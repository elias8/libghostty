import 'dart:typed_data';

import 'package:flterm/src/rendering/atlas_pool.dart';
import 'package:flutter/foundation.dart' show AsyncCallback, ValueNotifier;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:libghostty/libghostty.dart' show Terminal;

import '../fixture/terminal.dart';
import '../protocol.dart';
import '../report/model.dart';
import 'render_environment.dart';
import 'result.dart';

const _firstFrameReportKey = 'pending_first_frame_report';
const _reportKey = 'pending_frame_report';

/// Drives profile-mode terminal frames and returns Flutter timing summaries.
final class FrameBenchmarkHarness {
  final IntegrationTestWidgetsFlutterBinding _binding;
  final WidgetTester _tester;

  const FrameBenchmarkHarness(this._binding, this._tester);

  Map<String, Object?> get _reportData =>
      _binding.reportData ??= <String, Object?>{};

  Future<void> initialize() async {
    _tester.view
      ..devicePixelRatio = 1
      ..physicalSize = benchmarkSurfaceSize;
    addTearDown(_tester.view.resetDevicePixelRatio);
    addTearDown(_tester.view.resetPhysicalSize);
    final digest = await loadBenchmarkFonts();
    _reportData['font_digest'] = digest;
  }

  /// Measures fresh renderer mounts while excluding old-atlas disposal.
  Future<BenchmarkWorkloadResult> measureFirstTerminalFrames() async {
    final states = TerminalBenchmarkFixture.fullFrames(
      count: benchmarkFirstFrameMounts,
    );
    final resources = [
      for (final state in states)
        (
          terminal: Terminal(cols: benchmarkColumns, rows: benchmarkRows)
            ..write(state),
          atlasPool: AtlasPool(),
        ),
    ];
    final frameChanges = [for (final _ in resources) ValueNotifier(0)];
    final terminalListeners = [
      for (var index = 0; index < resources.length; index++)
        () => frameChanges[index].value++,
    ];
    for (var index = 0; index < resources.length; index++) {
      resources[index].terminal.addListener(terminalListeners[index]);
    }
    final retainedAtlasLeases = <AtlasLease>[];
    try {
      await _tester.pumpWidget(const SizedBox.shrink());
      await _binding.watchPerformance(() async {
        for (var sample = 0; sample < resources.length; sample++) {
          final resource = resources[sample];
          _binding.attachRootWidget(
            _binding.wrapWithDefaultView(
              BenchmarkTerminalSurface(
                key: ValueKey(sample),
                terminal: resource.terminal,
                frameChanges: frameChanges[sample],
                atlasPool: resource.atlasPool,
              ),
            ),
          );
          _binding.scheduleFrame();
          await _binding.endOfFrame;
          retainedAtlasLeases.add(retainBenchmarkAtlas(resource.atlasPool));
        }
      }, reportKey: _firstFrameReportKey);
      final summary = Map<String, Object?>.from(
        _reportData.remove(_firstFrameReportKey)! as Map<Object?, Object?>,
      );
      return framePerformanceResult(
        workload: .firstTerminalFrame,
        summary: summary,
      );
    } finally {
      await _tester.pumpWidget(const SizedBox.shrink());
      for (final lease in retainedAtlasLeases) {
        lease.release();
      }
      for (var index = 0; index < resources.length; index++) {
        resources[index].terminal.removeListener(terminalListeners[index]);
        frameChanges[index].dispose();
      }
      for (final resource in resources) {
        resource.atlasPool.dispose();
        resource.terminal.dispose();
      }
    }
  }

  Future<BenchmarkWorkloadResult> measureGlyphMissFrames() {
    final updates = TerminalBenchmarkFixture.glyphMissFrames(
      count: benchmarkGlyphMissFrames,
    );
    return _measureFrames(workload: .glyphMisses, updates: updates);
  }

  Future<BenchmarkWorkloadResult> measureSteadyFrames({
    required BenchmarkWorkload workload,
    List<Uint8List>? updates,
  }) async {
    final terminal = Terminal(cols: benchmarkColumns, rows: benchmarkRows);
    final frameChanges = ValueNotifier(0);
    void onTerminalChanged() => frameChanges.value++;
    terminal.addListener(onTerminalChanged);
    final atlasPool = AtlasPool();
    addTearDown(terminal.dispose);
    addTearDown(() {
      terminal.removeListener(onTerminalChanged);
      frameChanges.dispose();
    });
    addTearDown(atlasPool.dispose);
    addTearDown(() => _tester.pumpWidget(const SizedBox.shrink()));

    await _tester.pumpWidget(
      BenchmarkTerminalSurface(
        terminal: terminal,
        frameChanges: frameChanges,
        atlasPool: atlasPool,
      ),
    );
    terminal.write(TerminalBenchmarkFixture.fullFrames(count: 1).single);
    await _tester.pump();

    var update = 0;
    final summary = await _capture(() async {
      for (var frame = 0; frame < benchmarkSteadyFrames; frame++) {
        if (updates != null) {
          terminal.write(updates[update]);
          update = (update + 1) % updates.length;
        }
        await _renderFrame();
      }
    });
    return framePerformanceResult(workload: workload, summary: summary);
  }

  Future<Map<String, Object?>> _capture(AsyncCallback action) async {
    await _binding.watchPerformance(action, reportKey: _reportKey);
    return Map<String, Object?>.from(
      _reportData.remove(_reportKey)! as Map<Object?, Object?>,
    );
  }

  Future<BenchmarkWorkloadResult> _measureFrames({
    required BenchmarkWorkload workload,
    required List<Uint8List> updates,
  }) async {
    final terminal = Terminal(cols: benchmarkColumns, rows: benchmarkRows);
    final frameChanges = ValueNotifier(0);
    void onTerminalChanged() => frameChanges.value++;
    terminal.addListener(onTerminalChanged);
    final atlasPool = AtlasPool();
    addTearDown(terminal.dispose);
    addTearDown(() {
      terminal.removeListener(onTerminalChanged);
      frameChanges.dispose();
    });
    addTearDown(atlasPool.dispose);
    addTearDown(() => _tester.pumpWidget(const SizedBox.shrink()));
    await _tester.pumpWidget(
      BenchmarkTerminalSurface(
        terminal: terminal,
        frameChanges: frameChanges,
        atlasPool: atlasPool,
      ),
    );

    final summary = await _capture(() async {
      for (final update in updates) {
        terminal.write(update);
        await _renderFrame();
      }
    });
    return framePerformanceResult(workload: workload, summary: summary);
  }

  Future<void> _renderFrame() async {
    _binding.scheduleFrame();
    await _binding.endOfFrame;
  }
}

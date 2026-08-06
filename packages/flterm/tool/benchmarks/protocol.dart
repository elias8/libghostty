const benchmarkProtocolVersion = 2;
const benchmarkColumns = 120;
const benchmarkRows = 80;
const benchmarkSteadyFrames = 300;
const benchmarkGlyphMissFrames = 120;
const benchmarkFirstFrameSamples = 30;
const benchmarkFirstFrameMounts = 36;
const benchmarkMinimumFrameCaptureRatio = 0.95;

/// The user-facing performance boundary exercised by a workload.
enum BenchmarkWorkloadKind {
  /// Terminal input processing measured outside Flutter frame timing.
  input,

  /// Flutter UI and raster work measured from engine frame timings.
  frame,
}

/// Stable workload identities shared by measurement and reporting.
enum BenchmarkWorkload {
  /// Batched command output written in 128 KiB chunks.
  streamingOutput(
    'input.streaming_output',
    'streaming output, 128 KiB chunks',
    .input,
  ),

  /// Escape-heavy interactive output written in 4 KiB chunks.
  interactiveTui(
    'input.interactive_tui',
    'interactive TUI, 4 KiB chunks',
    .input,
  ),

  /// An unchanged terminal rendered repeatedly.
  cleanFrame('render.clean', 'clean frame', .frame),

  /// An editor-like update affecting three terminal rows.
  partialTui('render.partial_tui', 'partial TUI update', .frame),

  /// Styled output replacing every visible terminal row.
  fullOutput('render.full_output', 'full-screen output', .frame),

  /// Frames introducing glyphs not already present in the atlas.
  glyphMisses('render.glyph_misses', 'new glyphs', .frame),

  /// The first presentation of a fresh terminal renderer.
  firstTerminalFrame(
    'render.first_terminal_frame',
    'first terminal frame',
    .frame,
  );

  const BenchmarkWorkload(this.id, this.label, this.kind);

  final String id;
  final String label;
  final BenchmarkWorkloadKind kind;

  static final _byId = {for (final workload in values) workload.id: workload};

  /// Resolves the workload whose stable protocol identity is [id].
  static BenchmarkWorkload fromId(String id) {
    return _byId[id] ??
        (throw FormatException('Unknown benchmark workload "$id".'));
  }
}

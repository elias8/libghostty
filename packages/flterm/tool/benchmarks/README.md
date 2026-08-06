# flterm benchmarks

This suite measures the performance boundaries that directly affect terminal
users:

- processing output through `TerminalController.write`;
- drawing unchanged, partially updated, and fully updated terminal frames;
- rendering glyphs that are not already present in the atlas;
- presenting the first frame of a new terminal renderer.

It intentionally does not benchmark individual parsers, painters, caches, or
other implementation details. Those measurements are useful only when
investigating a specific subsystem and do not describe the experience of using
flterm.

## Measurement protocol

Rendering follows Flutter's
[integration performance testing](https://docs.flutter.dev/cookbook/testing/integration/profiling)
guidance. The suite runs through `flutter drive --profile` and records Flutter's
UI and raster frame timings. Debug widget-test timings are not performance
results.

Every workload uses:

- a terminal with 120 columns and 80 rows;
- fixed cell metrics and device pixel ratio 1;
- the example's bundled JetBrains Mono, Noto Sans JP, and Noto Emoji fonts;
- fixture generation and chunk preparation outside measured regions;
- sequential execution, with no concurrent performance workloads.

Input workloads perform ten unmeasured warmups, then collect at least 100
samples and five seconds of measured work. Each sample processes exactly
4 MiB. Rendering workloads schedule and await one real engine frame per
iteration at the runner display's cadence.

The input timer surrounds only the prepared calls to
`TerminalController.write`. Rendering results come from Flutter frame timings.
Terminal updates are applied before each measured frame, but their parser time
is not added to Flutter's UI or raster duration. Flutter can omit frame timings
at collection boundaries, so steady workloads require at least 95 percent of
their scheduled samples.

## Deterministic input

The suite uses two complementary input sources:

- A generated streaming-output corpus represents build logs and command output.
  It contains plain text, wrapping, 16/256/RGB styling, paths, numbers, CR/LF
  handling, and representative Unicode.
- A checked-in normalized editor-session transcript represents cursor-addressed
  TUI updates, status lines, commands, alternate-screen operation, and
  synchronized output. It contains no host paths, timing values, locale-derived
  content, or terminal replies.

Both corpora are exactly 4 MiB and are sliced into views before timing begins.
The report's fixture digest identifies the deterministic fixtures and bundled
fonts used for a run.

The workload mix follows established terminal benchmark practice: combine
realistic application-shaped traffic with focused synthetic stress cases.
Throughput alone is not treated as overall terminal performance because it
cannot describe frame consistency or latency.

## Workloads

### Input throughput

`streaming output, 128 KiB chunks` models batched output using the repository's
default PTY output batch size.

`interactive TUI, 4 KiB chunks` models smaller, escape-heavy interactive
updates.

Both workloads keep scrollback disabled so a sample measures terminal input
processing rather than unbounded history growth.

### Frame performance

`clean frame` measures steady frames without a terminal mutation.

`partial TUI update` changes exactly three rows using the editor transcript.

`full-screen output` changes every row using styled streaming output.

These workloads each record 300 frames after an initial warm frame.

`new glyphs` records 120 frames. Every frame introduces a disjoint set of CJK
glyphs and also exercises bold text, combining text, and emoji. The bundled
fonts keep glyph selection stable across machines.

`first terminal frame` records at least 30 independent first frames from fresh
renderer and render-cache instances. Terminal state and fonts are prepared
first. This measures flterm's first presentation, not Flutter process startup.

## Run locally

From `packages/flterm`:

```sh
dart run tool/benchmarks/run.dart
```

The command writes the following files under
`example/build/benchmark-results/`:

- `report.md`: the human-readable result;
- `results.json`: normalized, versioned benchmark data;
- `raw-flutter.json`: Flutter's complete integration response;
- `flutter.stdout.log` and `flutter.stderr.log`: runner diagnostics.

Use a custom output directory or revision label when needed:

```sh
dart run tool/benchmarks/run.dart \
  --output /tmp/flterm-results \
  --revision working-tree
```

For repeatable measurements, keep other applications idle and record the
hardware, Flutter version, display configuration, and power state.

## Continuous measurement

The `benchmark flterm` workflow runs after relevant flterm or libghostty
changes land on `main`, and it can also be started manually. It measures the
checked-out revision once, writes its report to the job summary, and uploads
the complete result bundle for 90 days.

Preserve result data and generated Markdown elsewhere when a report must
outlive artifact retention. Harness failures fail the benchmark workflow;
measured values alone do not fail it.

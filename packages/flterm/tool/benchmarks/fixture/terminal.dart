import 'dart:convert' show utf8;
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;

import '../protocol.dart';

/// Normalized content from an editor session.
///
/// Host paths, timing data, and terminal replies are intentionally absent.
/// The benchmark adds cursor addressing and synchronized-update boundaries.
const _editorTranscript = [
  (
    code: '  final controller = TerminalController();',
    status: ' NORMAL   terminal_view.dart                 42,7   63%',
    command: ':set number cursorline',
  ),
  (
    code: '  controller.write(output);',
    status: ' INSERT   terminal_view.dart                 43,29  65%',
    command: '-- INSERT --',
  ),
  (
    code: '  await tester.pump(const Duration(milliseconds: 16));',
    status: ' NORMAL   frame_render_benchmark.dart        98,12  51%',
    command: '/watchPerformance',
  ),
  (
    code: '  expect(result, isNotEmpty);',
    status: ' NORMAL   benchmark_report_test.dart         76,5   38%',
    command: ':write',
  ),
  (
    code: '  const symbols = "λ界é";',
    status: ' INSERT   terminal_benchmark_fixture.dart    31,28  24%',
    command: '-- INSERT --',
  ),
  (
    code: '  return renderer.buildFrame();',
    status: ' NORMAL   terminal_renderer.dart             211,3  72%',
    command: ':nohlsearch',
  ),
];
const _partialFrameDirtyRows = 3;

/// Deterministic input prepared outside every timed benchmark region.
abstract final class TerminalBenchmarkFixture {
  static const corpusLength = 4 * 1024 * 1024;

  static final streamingOutput = _corpus(
    _streamingRecords(),
  ).asUnmodifiableView();
  static final interactiveTuiOutput = _corpus(
    _tuiRecords(),
  ).asUnmodifiableView();

  static final inputDigest = _digest();

  /// Combines deterministic input and font identities for report provenance.
  static String benchmarkDigest(String fontDigest) {
    final input = utf8.encode('$inputDigest:$fontDigest');
    return 'sha256:${sha256.convert(input)}';
  }

  /// Splits [input] into views allocated before the timed write loop.
  static List<Uint8List> chunks(Uint8List input, int chunkSize) {
    if (chunkSize <= 0) {
      throw RangeError.range(chunkSize, 1, null, 'chunkSize');
    }
    if (input.length % chunkSize != 0) {
      throw ArgumentError.value(
        input.length,
        'input',
        'length must be divisible by chunkSize',
      );
    }
    return List.unmodifiable([
      for (var offset = 0; offset < input.length; offset += chunkSize)
        Uint8List.sublistView(input, offset, offset + chunkSize),
    ]);
  }

  /// Produces editor updates affecting three rows of the protocol surface.
  static List<Uint8List> partialFrames({required int count}) {
    _validateCount(count);
    return List.unmodifiable([
      for (var frame = 0; frame < count; frame++) _partialFrame(frame),
    ]);
  }

  /// Produces streaming-output updates affecting every protocol row.
  static List<Uint8List> fullFrames({required int count}) {
    _validateCount(count);
    return List.unmodifiable([
      for (var frame = 0; frame < count; frame++) _fullFrame(frame),
    ]);
  }

  /// Creates frames whose CJK glyph set is disjoint from earlier frames.
  static List<Uint8List> glyphMissFrames({required int count}) {
    _validateCount(count);
    return List.unmodifiable([
      for (var frame = 0; frame < count; frame++) _glyphFrame(frame),
    ]);
  }

  static List<Uint8List> _streamingRecords() => [
    for (var line = 0; line < 64; line++)
      Uint8List.fromList(
        utf8.encode(
          '\x1b[38;5;39mINFO\x1b[0m '
          'build/module_${line.toString().padLeft(2, '0')}.dart '
          '\x1b[38;2;120;200;80mcompleted\x1b[0m in ${17 + line} ms; '
          '\x1b[32m${100 + line} checks passed\x1b[0m; λ界 e\u0301\r\n',
        ),
      ),
  ];

  static List<Uint8List> _tuiRecords() => [
    Uint8List.fromList(utf8.encode('\x1b[?1049h\x1b[2J\x1b[H')),
    for (var index = 0; index < _editorTranscript.length; index++)
      _partialFrame(index),
  ];

  static Uint8List _corpus(List<Uint8List> records) {
    final output = Uint8List(corpusLength);
    var offset = 0;
    var record = 0;
    while (offset + records[record].length <= output.length) {
      final bytes = records[record];
      output.setRange(offset, offset + bytes.length, bytes);
      offset += bytes.length;
      record = (record + 1) % records.length;
    }
    output.fillRange(offset, output.length, 0x20);
    return output;
  }

  static Uint8List _partialFrame(int frame) {
    final transcript = _editorTranscript[frame % _editorTranscript.length];
    final content = [transcript.code, transcript.status, transcript.command];
    final buffer = StringBuffer('\x1b[?2026h');
    for (var index = 0; index < _partialFrameDirtyRows; index++) {
      final row = benchmarkRows - _partialFrameDirtyRows + index + 1;
      buffer
        ..write('\x1b[$row;1H\x1b[2K')
        ..write(content[index % content.length])
        ..write(' #${frame.toString().padLeft(3, '0')}');
    }
    buffer.write('\x1b[?2026l');
    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  static Uint8List _fullFrame(int frame) {
    final buffer = StringBuffer('\x1b[?2026h');
    for (var row = 0; row < benchmarkRows; row++) {
      buffer.write(
        '\x1b[${row + 1};1H\x1b[2K'
        '\x1b[38;5;${32 + row % 96}m'
        'worker ${row.toString().padLeft(2, '0')} '
        'frame ${frame.toString().padLeft(3, '0')} '
        'compile λ界 e\u0301 \x1b[0m',
      );
    }
    buffer.write('\x1b[?2026l');
    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  static Uint8List _glyphFrame(int frame) {
    final cjk = String.fromCharCodes([
      for (var offset = 0; offset < 4; offset++) 0x4E00 + frame * 4 + offset,
    ]);
    final emoji = String.fromCharCode(0x1F600 + frame % 16);
    final frameNumber = frame.toString().padLeft(3, '0');
    return Uint8List.fromList(
      utf8.encode(
        [
          '\x1b[?2026h',
          '\x1b[20;1H\x1b[2K\x1b[1m$cjk\x1b[0m',
          '\x1b[21;1H\x1b[2K$emoji grapheme e\u0301',
          '\x1b[22;1H\x1b[2Kcache miss $frameNumber',
          '\x1b[?2026l',
        ].join(),
      ),
    );
  }

  static String _digest() {
    final components = [
      sha256.convert(streamingOutput),
      sha256.convert(interactiveTuiOutput),
      ...partialFrames(count: benchmarkSteadyFrames).map(sha256.convert),
      ...fullFrames(count: benchmarkSteadyFrames).map(sha256.convert),
      ...glyphMissFrames(count: benchmarkGlyphMissFrames).map(sha256.convert),
    ].join(':');
    return 'sha256:${sha256.convert(utf8.encode(components))}';
  }

  static void _validateCount(int count) {
    if (count <= 0) throw RangeError.range(count, 1, null, 'count');
  }
}

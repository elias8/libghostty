import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../../../tool/benchmarks/frame/render_environment.dart'
    show benchmarkFontDigest;

void main() {
  group('benchmarkFontDigest', () {
    ByteData data(List<int> bytes) {
      return Uint8List.fromList(bytes).buffer.asByteData();
    }

    String digest({
      List<int> regular = const [1],
      List<int> bold = const [2],
      List<int> textFallback = const [3],
      List<int> emojiFallback = const [4],
    }) {
      return benchmarkFontDigest(
        jetBrainsMonoRegular: data(regular),
        jetBrainsMonoBold: data(bold),
        notoSansJp: data(textFallback),
        notoEmoji: data(emojiFallback),
      );
    }

    test('captures every bundled font', () {
      final baseline = digest();

      expect(digest(regular: [5]), isNot(baseline));
      expect(digest(bold: [5]), isNot(baseline));
      expect(digest(textFallback: [5]), isNot(baseline));
      expect(digest(emojiFallback: [5]), isNot(baseline));
    });
  });
}

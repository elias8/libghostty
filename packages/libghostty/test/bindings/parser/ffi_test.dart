@Tags(['ffi'])
library;

import 'dart:convert';

import 'package:libghostty/src/bindings/parser/ffi.dart';
import 'package:libghostty/src/generated/libghostty_enums.g.dart';
import 'package:test/test.dart';

void main() {
  group('FfiParserBindings', () {
    late FfiParserBindings bindings;

    setUp(() {
      bindings = const FfiParserBindings();
    });

    test('parses an OSC window title through direct bindings', () {
      final parser = bindings.oscNew(unknownMaxBytes: 0);
      addTearDown(() => bindings.oscFree(parser));

      final bytes = utf8.encode('0;Terminal');
      bindings.oscFeedByte(parser, bytes[0]);
      bindings.oscFeedByte(parser, bytes[1]);
      bindings.oscFeedByte(parser, bytes[2]);
      bindings.oscFeedByte(parser, bytes[3]);
      bindings.oscFeedByte(parser, bytes[4]);
      bindings.oscFeedByte(parser, bytes[5]);
      bindings.oscFeedByte(parser, bytes[6]);
      bindings.oscFeedByte(parser, bytes[7]);
      bindings.oscFeedByte(parser, bytes[8]);
      bindings.oscFeedByte(parser, bytes[9]);
      final command = bindings.oscEnd(parser, 0x07);

      expect(
        bindings.oscCommandType(command),
        OscCommandType.changeWindowTitle,
      );
      expect(bindings.oscCommandWindowTitle(command), 'Terminal');
    });

    test('parses SGR parameters and reports exhaustion as absence', () {
      final parser = bindings.sgrNew();
      addTearDown(() => bindings.sgrFree(parser));

      bindings.sgrSetParams(parser, [1, 31], null);

      expect(bindings.sgrNext(parser)?.tag, SgrAttributeTag.bold);
      expect(bindings.sgrNext(parser)?.tag, SgrAttributeTag.fg8);
      expect(bindings.sgrNext(parser), isNull);
    });
  });
}

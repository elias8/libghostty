import 'package:flterm/src/foundation/terminal_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart';

void main() {
  group('TerminalConfig', () {
    group('constructor', () {
      test('uses terminal defaults', () {
        const config = TerminalConfig();

        expect(config.cols, 80);
        expect(config.rows, 24);
        expect(config.scrollbackMaxBytes, 10000);
        expect(config.scrollbackMaxLines, isNull);
        expect(config.cursorStyle, CursorShape.block);
        expect(config.cursorBlink, isNull);
        expect(config.glyphProtocol, isFalse);
        expect(config.apcBufferLimit, TerminalConfig.defaultApcBufferLimit);
        expect(config.scrollToBottom, ScrollToBottom.onKeystroke);
        expect(config.selectionClearOnTyping, isTrue);
        expect(config.enquiryResponse, isEmpty);
      });

      test('custom modes override defaults', () {
        final modes = <TerminalMode, bool>{
          ...TerminalConfig.defaultModes,
          const TerminalMode.autoWrap(): false,
        };
        final config = TerminalConfig(modes: modes);

        expect(config.modes[const TerminalMode.autoWrap()], isFalse);
        expect(config.modes[const TerminalMode.cursorBlinking()], isTrue);
      });
    });

    group('defaultModes', () {
      test('contains terminal mode defaults', () {
        const modes = TerminalConfig.defaultModes;

        expect(modes[const TerminalMode.srm()], isTrue);
        expect(modes[const TerminalMode.autoWrap()], isTrue);
        expect(modes[const TerminalMode.cursorBlinking()], isTrue);
        expect(modes[const TerminalMode.cursorVisible()], isTrue);
        expect(modes[const TerminalMode.alternateScroll()], isTrue);
        expect(modes[const TerminalMode.numlockKeypad()], isTrue);
        expect(modes[const TerminalMode.altEscPrefix()], isTrue);
        expect(modes[const TerminalMode.graphemeCluster()], isTrue);
        expect(modes.length, 8);
      });
    });

    group('copyWith', () {
      test('replaces specified fields and preserves the rest', () {
        const original = TerminalConfig(
          cols: 120,
          rows: 40,
          scrollbackMaxBytes: 50000,
          scrollbackMaxLines: 500,
        );
        final copy = original.copyWith(cols: 80);

        expect(copy.cols, 80);
        expect(copy.rows, 40);
        expect(copy.scrollbackMaxBytes, 50000);
        expect(copy.scrollbackMaxLines, 500);

        const config = TerminalConfig();
        final updated = config.copyWith(
          scrollbackMaxBytes: 99999,
          scrollbackMaxLines: 999,
          apcBufferLimit: 1024,
          glyphProtocol: true,
          cursorBlink: false,
        );

        expect(updated.scrollbackMaxBytes, 99999);
        expect(updated.scrollbackMaxLines, 999);
        expect(updated.apcBufferLimit, 1024);
        expect(updated.glyphProtocol, isTrue);
        expect(updated.cursorBlink, isFalse);
        expect(updated.cols, config.cols);
      });
    });

    group('equality', () {
      test('compares configs by value', () {
        const a = TerminalConfig();
        const b = TerminalConfig();

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));

        const differentCols = TerminalConfig(cols: 120);
        expect(a, isNot(equals(differentCols)));

        const differentModes = TerminalConfig(
          modes: {TerminalMode.autoWrap(): false},
        );
        expect(
          const TerminalConfig(modes: {TerminalMode.autoWrap(): true}),
          isNot(equals(differentModes)),
        );

        const trueBlink = TerminalConfig(cursorBlink: true);
        const falseBlink = TerminalConfig(cursorBlink: false);
        expect(a, isNot(equals(trueBlink)));
        expect(a, isNot(equals(falseBlink)));
        expect(trueBlink, isNot(equals(falseBlink)));

        const apcA = TerminalConfig(apcBufferLimit: 1024);
        const apcB = TerminalConfig(apcBufferLimit: 2048);
        const apcC = TerminalConfig(apcBufferLimit: 1024);
        expect(apcA, equals(apcC));
        expect(apcA, isNot(equals(apcB)));

        const glyphProtocol = TerminalConfig(glyphProtocol: true);
        expect(a, isNot(equals(glyphProtocol)));

        const byteLimited = TerminalConfig(scrollbackMaxBytes: 1024);
        const lineLimited = TerminalConfig(scrollbackMaxLines: 1024);
        expect(a, isNot(equals(byteLimited)));
        expect(a, isNot(equals(lineLimited)));
      });

      test('ignores map order', () {
        const a = TerminalConfig(
          modes: {
            TerminalMode.autoWrap(): true,
            TerminalMode.cursorBlinking(): true,
          },
        );
        const b = TerminalConfig(
          modes: {
            TerminalMode.cursorBlinking(): true,
            TerminalMode.autoWrap(): true,
          },
        );

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });
    });
  });
}

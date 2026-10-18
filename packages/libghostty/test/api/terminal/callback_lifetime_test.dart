import 'dart:typed_data';

import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

import '../../helpers/setup.dart';

void main() {
  group('Terminal callbacks', () {
    setUp(() => testEnvironment);

    test('retains self-capturing callbacks until replacement or clear', () {
      final terminal = Terminal(cols: 8, rows: 2);
      addTearDown(terminal.dispose);
      final titles = <String>[];

      terminal.onTitleChanged = () => titles.add(terminal.title);
      terminal.write(Uint8List.fromList('\x1b]2;first\x07'.codeUnits));
      terminal.onTitleChanged = () => titles.add('next ${terminal.title}');
      terminal.write(Uint8List.fromList('\x1b]2;second\x07'.codeUnits));
      terminal.onTitleChanged = null;
      terminal.write(Uint8List.fromList('\x1b]2;third\x07'.codeUnits));

      expect(titles, ['first', 'next second']);
      expect(terminal.title, 'third');
    });

    test('retains getter and value callbacks across repeated replies', () {
      final terminal = Terminal(cols: 8, rows: 2);
      addTearDown(terminal.dispose);
      final replies = <int>[];
      terminal.onWritePty = replies.addAll;

      terminal.onEnquiry = () => Uint8List.fromList([terminal.geometry.cols]);
      terminal.write(Uint8List.fromList([5, 5]));

      expect(replies, [8, 8]);

      terminal.onEnquiry = () => Uint8List.fromList([42]);
      terminal.write(Uint8List.fromList([5]));
      terminal.onEnquiry = null;
      terminal.write(Uint8List.fromList([5]));

      expect(replies, [8, 8, 42]);
    });

    test('preserves nested terminal callbacks and exception propagation', () {
      final outer = Terminal(cols: 8, rows: 2);
      final inner = Terminal(cols: 8, rows: 2);
      addTearDown(outer.dispose);
      addTearDown(inner.dispose);
      final events = <String>[];
      final failure = StateError('callback failure');
      inner.onBell = () {
        events.add('inner ${inner.geometry.cols}');
        throw failure;
      };
      outer.onBell = () {
        events.add('outer ${outer.geometry.cols}');
        inner.write(Uint8List.fromList([7]));
      };

      expect(
        () => outer.write(Uint8List.fromList([7])),
        throwsA(same(failure)),
      );
      expect(events, ['outer 8', 'inner 8']);

      inner.onBell = null;
      outer.write(Uint8List.fromList([7]));

      expect(events, ['outer 8', 'inner 8', 'outer 8']);
    });

    test('disposal rejects callback replacement and remains idempotent', () {
      final terminal = Terminal(cols: 8, rows: 2);
      terminal.onBell = () => terminal.title;
      terminal.dispose();

      expect(terminal.dispose, returnsNormally);
      expect(() => terminal.onBell = () {}, throwsStateError);
      expect(() => terminal.onBell = null, throwsStateError);
    });
  });
}

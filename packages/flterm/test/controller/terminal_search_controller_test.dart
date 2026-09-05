@Tags(['ffi'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flterm/flterm.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TerminalSearchController', () {
    late TerminalController controller;

    setUp(() {
      controller = TerminalController();
    });

    tearDown(() => controller.dispose());

    group('initial state', () {
      test('has no query and uses the default scroll policy', () {
        final search = controller.search;

        expect(search.query, isNull);
        expect(search.isSearching, isFalse);
        expect(search.totalMatches, 0);
        expect(search.selectedIndex, isNull);
        expect(search.selectedMatch, isNull);
        expect(search.matches, isEmpty);
        expect(search.viewportMatches, isEmpty);
        expect(search.scrollPolicy, SearchScroll.ifNeeded);
      });
    });

    group('search', () {
      testWidgets('discovers matches without exposing incremental work', (
        tester,
      ) async {
        controller.write(Uint8List.fromList(utf8.encode('hello world hello')));

        controller.search.search('hello');
        await tester.pumpAndSettle();

        expect(controller.search.query, 'hello');
        expect(controller.search.isSearching, isFalse);
        expect(controller.search.totalMatches, 2);
        expect(controller.search.matches, hasLength(2));
        expect(controller.search.viewportMatches, hasLength(2));
      });

      testWidgets('refreshes results after terminal output', (tester) async {
        controller.write(Uint8List.fromList(utf8.encode('hello')));
        controller.search.search('hello');
        await tester.pumpAndSettle();

        controller.write(Uint8List.fromList(utf8.encode(' hello')));
        await tester.pumpAndSettle();

        expect(controller.search.totalMatches, 2);
      });

      testWidgets('does not expose invalidated results while catching up', (
        tester,
      ) async {
        controller.write(Uint8List.fromList(utf8.encode('hello')));
        controller.search.search('hello');
        await tester.pumpAndSettle();

        controller.write(Uint8List.fromList(utf8.encode(' world')));

        expect(controller.search.isSearching, isTrue);
        expect(controller.search.matches, isEmpty);
        expect(controller.search.viewportMatches, isEmpty);
        expect(controller.search.selectedMatch, isNull);
        await tester.pumpAndSettle();
      });

      testWidgets('clears an empty query', (tester) async {
        controller.write(Uint8List.fromList(utf8.encode('hello')));
        controller.search.search('hello');
        await tester.pumpAndSettle();

        controller.search.search('');

        expect(controller.search.query, isNull);
        expect(controller.search.matches, isEmpty);
      });

      testWidgets('preserves selection for case-insensitive resubmission', (
        tester,
      ) async {
        controller.write(Uint8List.fromList(utf8.encode('hello world hello')));
        controller.search.search('hello');
        controller.search.next();
        final selectedIndex = controller.search.selectedIndex;

        controller.search.search('HELLO');

        expect(controller.search.selectedIndex, selectedIndex);
        await tester.pumpAndSettle();

        expect(controller.search.selectedIndex, selectedIndex);
      });

      testWidgets('tracks results independently across terminal screens', (
        tester,
      ) async {
        controller.write(Uint8List.fromList(utf8.encode('primary')));
        controller.search.search('primary');
        await tester.pumpAndSettle();
        expect(controller.search.totalMatches, 1);

        controller.write(Uint8List.fromList(utf8.encode('\x1b[?1049h')));
        await tester.pumpAndSettle();
        expect(controller.search.totalMatches, 0);

        controller.write(Uint8List.fromList(utf8.encode('\x1b[?1049l')));
        await tester.pumpAndSettle();
        expect(controller.search.totalMatches, 1);
      });
    });

    group('navigation', () {
      test('selects matches in both directions', () {
        controller.write(Uint8List.fromList(utf8.encode('hello world hello')));
        controller.search.search('hello');

        controller.search.next();
        final first = controller.search.selectedMatch;
        controller.search.previous();

        expect(first, isNotNull);
        expect(controller.search.selectedMatch, isNotNull);
        expect(controller.search.selectedMatch, isNot(first));
      });

      test('supports manual viewport control', () {
        controller.search.scrollPolicy = SearchScroll.none;

        expect(controller.search.scrollPolicy, SearchScroll.none);
      });
    });

    group('lifecycle', () {
      test('becomes unusable with its terminal controller', () {
        final search = controller.search;

        controller.dispose();

        expect(() => search.query, throwsStateError);
      });
    });
  });
}

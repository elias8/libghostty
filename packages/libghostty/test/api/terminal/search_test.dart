import 'dart:typed_data';

import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

import '../../helpers/setup.dart';

void main() {
  setUp(() => testEnvironment);

  group('Search', () {
    late Terminal terminal;
    late Search search;

    setUp(() {
      terminal = Terminal(cols: 80, rows: 24);
      search = Search(terminal);
    });

    tearDown(() {
      search.dispose();
      terminal.dispose();
    });

    group('dispose', () {
      test('is idempotent and rejects operations afterward', () {
        search.dispose();

        expect(search.dispose, returnsNormally);
        expect(() => search.matches, throwsStateError);
        expect(() => search.needle, throwsStateError);
        expect(() => search.selectedIndex, throwsStateError);
        expect(() => search.selectedMatch, throwsStateError);
        expect(() => search.selectScroll, throwsStateError);
        expect(() => search.selectScroll = SearchScroll.none, throwsStateError);
        expect(() => search.status, throwsStateError);
        expect(() => search.totalMatches, throwsStateError);
        expect(() => search.viewportMatches, throwsStateError);
        expect(search.feed, throwsStateError);
        expect(search.run, throwsStateError);
        expect(search.selectNext, throwsStateError);
        expect(search.selectPrevious, throwsStateError);
        expect(() => search.setNeedle('hello'), throwsStateError);
        expect(search.tick, throwsStateError);
      });

      test('succeeds after terminal disposal', () {
        terminal.dispose();

        expect(search.run, throwsStateError);
        expect(search.dispose, returnsNormally);
      });
    });

    test('finds matches after running the search', () {
      terminal.write(Uint8List.fromList('hello world hello'.codeUnits));

      search.setNeedle('hello');
      search.run();

      expect(search.status, SearchStatus.complete);
      expect(search.totalMatches, 2);
      expect(search.matches, hasLength(2));
      expect(search.viewportMatches, hasLength(2));
    });

    test('selects matches and exposes the selected range', () {
      terminal.write(Uint8List.fromList('hello world hello'.codeUnits));

      search.setNeedle('hello');
      search.run();
      search.selectNext();

      expect(search.selectedIndex, 0);
      expect(search.selectedMatch, isNotNull);
      expect(
        search.selectedMatch!.end.positionIn(PointTag.active)!.col,
        greaterThan(0),
      );
    });
  });
}

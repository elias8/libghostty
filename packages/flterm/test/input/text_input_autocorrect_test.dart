import 'package:flterm/src/input/text_input_session.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The delta the platform sends when autocorrect rewrites a finished word:
/// the typed run is replaced by the corrected one.
TextEditingDelta _correction({
  required String oldText,
  required String replaced,
  required String replacement,
}) {
  final start = oldText.indexOf(replaced);
  return TextEditingDeltaReplacement(
    oldText: oldText,
    replacementText: replacement,
    replacedRange: TextRange(start: start, end: start + replaced.length),
    selection: TextSelection.collapsed(offset: start + replacement.length),
    composing: TextRange.empty,
  );
}

void main() {
  late TextInputSession client;
  late List<String> committed;
  late List<int> deletions;

  setUp(() {
    committed = [];
    deletions = [];
    client = TextInputSession()
      ..onTextCommitted = committed.add
      ..onDelete = deletions.add;
  });

  test('autocorrect off: a replacement sends only the new text', () {
    client.updateEditingValueWithDeltas([
      _correction(oldText: ' esdi', replaced: 'esdi', replacement: 'если'),
    ]);

    expect(committed, ['если']);
    // No backspaces — the host would be editing a line nobody asked it to.
    expect(deletions, isEmpty);
  });

  test('autocorrect on: a replacement takes back what it replaces', () {
    client.autocorrect = true;

    client.updateEditingValueWithDeltas([
      _correction(oldText: ' esdi', replaced: 'esdi', replacement: 'если'),
    ]);

    // Four characters were already sent to the host, so four come back off
    // before the correction lands.
    expect(deletions, [4]);
    expect(committed, ['если']);
  });

  test('autocorrect on: the platform keeps seeing the word being typed', () {
    client.autocorrect = true;

    // Type "hel" one character at a time, the way a soft keyboard reports it.
    for (final (i, char) in ['h', 'e', 'l'].indexed) {
      final text = ' ${'hel'.substring(0, i)}';
      client.updateEditingValueWithDeltas([
        TextEditingDeltaInsertion(
          oldText: text,
          textInserted: char,
          insertionOffset: text.length,
          selection: TextSelection.collapsed(offset: text.length + 1),
          composing: TextRange.empty,
        ),
      ]);
    }

    expect(committed, ['h', 'e', 'l']);
    // Autocorrect can only fix a word the keyboard can still see. Resetting
    // the editing value after every character leaves it nothing to correct.
    expect(client.currentTextEditingValue.text, ' hel');
  });

  test('autocorrect on: an IME commit sends only its own text', () {
    client.autocorrect = true;

    for (final (i, char) in ['h', 'e'].indexed) {
      final text = ' ${'he'.substring(0, i)}';
      client.updateEditingValueWithDeltas([
        TextEditingDeltaInsertion(
          oldText: text,
          textInserted: char,
          insertionOffset: text.length,
          selection: TextSelection.collapsed(offset: text.length + 1),
          composing: TextRange.empty,
        ),
      ]);
    }
    client
      ..updateEditingValueWithDeltas([
        const TextEditingDeltaInsertion(
          oldText: ' he',
          textInserted: 'ni',
          insertionOffset: 3,
          selection: TextSelection.collapsed(offset: 5),
          composing: TextRange(start: 3, end: 5),
        ),
      ])
      ..updateEditingValueWithDeltas([
        const TextEditingDeltaNonTextUpdate(
          oldText: ' he\u4f60',
          selection: TextSelection.collapsed(offset: 4),
          composing: TextRange.empty,
        ),
      ]);

    // "he" is still in the retained buffer but already reached the host.
    expect(committed, ['h', 'e', '\u4f60']);
  });

  test('autocorrect on: Enter starts the next line from a clean buffer', () {
    client.autocorrect = true;
    client.updateEditingValueWithDeltas([
      const TextEditingDeltaInsertion(
        oldText: ' ',
        textInserted: 'ls',
        insertionOffset: 1,
        selection: TextSelection.collapsed(offset: 3),
        composing: TextRange.empty,
      ),
    ]);
    expect(client.currentTextEditingValue.text, ' ls');

    client.performAction(TextInputAction.newline);

    expect(client.currentTextEditingValue.text, ' ');
  });

  test('autocorrect off: the buffer resets after every character', () {
    // The buffer resets after every character, so each one lands on ' '.
    const text = ' ';
    for (final char in ['h', 'i']) {
      client.updateEditingValueWithDeltas([
        TextEditingDeltaInsertion(
          oldText: text,
          textInserted: char,
          insertionOffset: text.length,
          selection: const TextSelection.collapsed(offset: text.length + 1),
          composing: TextRange.empty,
        ),
      ]);
    }

    expect(committed, ['h', 'i']);
    expect(client.currentTextEditingValue.text, ' ');
  });

  test('autocorrect on: deleting past the buffer re-primes the sentinel', () {
    client.autocorrect = true;

    // Text that reached the host without going through the keyboard (a paste)
    // leaves the platform only the sentinel to delete.
    client.updateEditingValueWithDeltas([
      const TextEditingDeltaDeletion(
        oldText: ' ',
        deletedRange: TextRange(start: 0, end: 1),
        selection: TextSelection.collapsed(offset: 0),
        composing: TextRange.empty,
      ),
    ]);

    expect(deletions, [1]);
    // An empty field means the platform stops reporting Backspace, so the
    // sentinel has to come back or every further press is swallowed.
    expect(client.currentTextEditingValue.text, ' ');
  });

  test('autocorrect on: a partly eaten buffer is kept', () {
    client.autocorrect = true;
    client.updateEditingValueWithDeltas([
      const TextEditingDeltaInsertion(
        oldText: ' ',
        textInserted: 'hi',
        insertionOffset: 1,
        selection: TextSelection.collapsed(offset: 3),
        composing: TextRange.empty,
      ),
      const TextEditingDeltaDeletion(
        oldText: ' hi',
        deletedRange: TextRange(start: 2, end: 3),
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange.empty,
      ),
    ]);

    expect(deletions, [1]);
    // 'h' is still there for autocorrect to work on.
    expect(client.currentTextEditingValue.text, ' h');
  });

  test('autocorrect on: plain typing still sends no backspaces', () {
    client.autocorrect = true;

    client.updateEditingValueWithDeltas([
      const TextEditingDeltaInsertion(
        oldText: ' ',
        textInserted: 'a',
        insertionOffset: 1,
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange.empty,
      ),
    ]);

    expect(committed, ['a']);
    expect(deletions, isEmpty);
  });
}

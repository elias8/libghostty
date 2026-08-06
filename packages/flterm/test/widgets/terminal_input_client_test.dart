import 'package:flterm/src/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TerminalInputClient', () {
    late TerminalInputClient handler;
    late List<String> commits;
    late List<int> deletes;
    late List<void> newlines;

    List<MethodCall> recordTextInputCalls() {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.textInput, (call) async {
            calls.add(call);
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.textInput, null);
      });
      return calls;
    }

    List<MethodCall> textInputSetClientCalls(List<MethodCall> calls) {
      return calls
          .where((call) => call.method == 'TextInput.setClient')
          .toList();
    }

    Map<String, Object?> textInputConfig(List<MethodCall> calls) {
      final setClientCall = calls.singleWhere(
        (call) => call.method == 'TextInput.setClient',
      );
      final args = setClientCall.arguments as List<Object?>;
      return args[1]! as Map<String, Object?>;
    }

    Map<String, Object?> textInputUpdateConfig(List<MethodCall> calls) {
      final updateConfigCall = calls.singleWhere(
        (call) => call.method == 'TextInput.updateConfig',
      );
      return updateConfigCall.arguments! as Map<String, Object?>;
    }

    Map<String, Object?> textInputCall(List<MethodCall> calls, String method) {
      final call = calls.singleWhere((call) => call.method == method);
      return call.arguments! as Map<String, Object?>;
    }

    setUp(() {
      handler = TerminalInputClient()..viewId = 0;
      commits = [];
      deletes = [];
      newlines = [];
      handler.onTextCommitted = commits.add;
      handler.onDelete = deletes.add;
      handler.onNewline = () => newlines.add(null);
    });

    tearDown(() => handler.detach());

    group('updateEditingValueWithDeltas', () {
      test('commits inserted text', () {
        handler.updateEditingValueWithDeltas([
          const TextEditingDeltaInsertion(
            oldText: '',
            textInserted: 'a',
            insertionOffset: 0,
            selection: TextSelection.collapsed(offset: 1),
            composing: TextRange.empty,
          ),
        ]);

        expect(commits, ['a']);
      });

      test('commits multi-character insertion', () {
        handler.updateEditingValueWithDeltas([
          const TextEditingDeltaInsertion(
            oldText: '',
            textInserted: 'hello',
            insertionOffset: 0,
            selection: TextSelection.collapsed(offset: 5),
            composing: TextRange.empty,
          ),
        ]);

        expect(commits, ['hello']);
      });

      test('commits text around newlines', () {
        handler.updateEditingValueWithDeltas([
          const TextEditingDeltaInsertion(
            oldText: '',
            textInserted: 'a\nb\rc',
            insertionOffset: 0,
            selection: TextSelection.collapsed(offset: 5),
            composing: TextRange.empty,
          ),
        ]);

        expect(commits, ['a', 'b', 'c']);
      });

      test('reports inserted newlines', () {
        handler.updateEditingValueWithDeltas([
          const TextEditingDeltaInsertion(
            oldText: '',
            textInserted: 'a\nb\rc',
            insertionOffset: 0,
            selection: TextSelection.collapsed(offset: 5),
            composing: TextRange.empty,
          ),
        ]);

        expect(newlines, hasLength(2));
      });

      test('deduplicates newline action after newline insertion', () {
        handler.updateEditingValueWithDeltas([
          const TextEditingDeltaInsertion(
            oldText: '',
            textInserted: '\n',
            insertionOffset: 0,
            selection: TextSelection.collapsed(offset: 1),
            composing: TextRange.empty,
          ),
        ]);

        handler.performAction(TextInputAction.newline);

        expect(newlines, hasLength(1));
      });

      test('deduplicates newline insertion after newline action', () {
        handler.performAction(TextInputAction.newline);

        handler.updateEditingValueWithDeltas([
          const TextEditingDeltaInsertion(
            oldText: '',
            textInserted: '\n',
            insertionOffset: 0,
            selection: TextSelection.collapsed(offset: 1),
            composing: TextRange.empty,
          ),
        ]);

        expect(newlines, hasLength(1));
      });

      test('reports deletion character count', () {
        handler.updateEditingValueWithDeltas([
          const TextEditingDeltaInsertion(
            oldText: '',
            textInserted: 'ab',
            insertionOffset: 0,
            selection: TextSelection.collapsed(offset: 2),
            composing: TextRange.empty,
          ),
        ]);
        commits.clear();

        handler.updateEditingValueWithDeltas([
          const TextEditingDeltaDeletion(
            oldText: 'ab',
            deletedRange: TextRange(start: 1, end: 2),
            selection: TextSelection.collapsed(offset: 1),
            composing: TextRange.empty,
          ),
        ]);

        expect(deletes, [1]);
      });

      test('reports multi-character deletion count', () {
        handler.updateEditingValueWithDeltas([
          const TextEditingDeltaDeletion(
            oldText: 'abc',
            deletedRange: TextRange(start: 0, end: 3),
            selection: TextSelection.collapsed(offset: 0),
            composing: TextRange.empty,
          ),
        ]);

        expect(deletes, [3]);
      });

      test('does not commit composing insertion', () {
        handler.updateEditingValueWithDeltas([
          const TextEditingDeltaInsertion(
            oldText: '',
            textInserted: 'n',
            insertionOffset: 0,
            selection: TextSelection.collapsed(offset: 1),
            composing: TextRange(start: 0, end: 1),
          ),
        ]);

        expect(commits, isEmpty);
      });

      test('does not commit sentinel-only composing insertion', () {
        final preedit = <String>[];
        handler.onPreeditChanged = preedit.add;

        handler.updateEditingValueWithDeltas([
          const TextEditingDeltaInsertion(
            oldText: '',
            textInserted: ' ',
            insertionOffset: 0,
            selection: TextSelection.collapsed(offset: 1),
            composing: TextRange(start: 0, end: 1),
          ),
        ]);

        expect(commits, isEmpty);
        expect(preedit, isEmpty);
        expect(handler.hasActiveComposition, isTrue);
      });

      test('commits final composing text', () {
        handler.updateEditingValueWithDeltas([
          const TextEditingDeltaInsertion(
            oldText: '',
            textInserted: 'n',
            insertionOffset: 0,
            selection: TextSelection.collapsed(offset: 1),
            composing: TextRange(start: 0, end: 1),
          ),
        ]);

        handler.updateEditingValueWithDeltas([
          const TextEditingDeltaReplacement(
            oldText: 'n',
            replacementText: 'ni',
            replacedRange: TextRange(start: 0, end: 1),
            selection: TextSelection.collapsed(offset: 2),
            composing: TextRange(start: 0, end: 2),
          ),
        ]);

        expect(commits, isEmpty);

        handler.updateEditingValueWithDeltas([
          const TextEditingDeltaReplacement(
            oldText: 'ni',
            replacementText: '\u4f60',
            replacedRange: TextRange(start: 0, end: 2),
            selection: TextSelection.collapsed(offset: 1),
            composing: TextRange.empty,
          ),
        ]);

        expect(commits, ['\u4f60']);
      });

      test('commits composing text finalized by non-text update', () {
        final preedit = <String>[];
        handler.onPreeditChanged = preedit.add;

        handler.updateEditingValueWithDeltas([
          const TextEditingDeltaInsertion(
            oldText: '',
            textInserted: 'ni',
            insertionOffset: 0,
            selection: TextSelection.collapsed(offset: 2),
            composing: TextRange(start: 0, end: 2),
          ),
        ]);

        handler.updateEditingValueWithDeltas([
          const TextEditingDeltaNonTextUpdate(
            oldText: '\u4f60',
            selection: TextSelection.collapsed(offset: 1),
            composing: TextRange.empty,
          ),
        ]);

        expect(commits, ['\u4f60']);
        expect(preedit, ['ni', '']);
      });

      test('ignores deletion that clears preedit text before commit', () {
        handler.updateEditingValueWithDeltas([
          const TextEditingDeltaInsertion(
            oldText: '',
            textInserted: 'ni',
            insertionOffset: 0,
            selection: TextSelection.collapsed(offset: 2),
            composing: TextRange(start: 0, end: 2),
          ),
        ]);

        handler.updateEditingValueWithDeltas([
          const TextEditingDeltaDeletion(
            oldText: 'ni',
            deletedRange: TextRange(start: 0, end: 2),
            selection: TextSelection.collapsed(offset: 0),
            composing: TextRange.empty,
          ),
          const TextEditingDeltaInsertion(
            oldText: '',
            textInserted: '\u4f60',
            insertionOffset: 0,
            selection: TextSelection.collapsed(offset: 1),
            composing: TextRange.empty,
          ),
        ]);

        expect(deletes, isEmpty);
        expect(commits, ['\u4f60']);
      });

      test('reports preedit updates', () {
        final preedit = <String>[];
        handler.onPreeditChanged = preedit.add;

        handler.updateEditingValueWithDeltas([
          const TextEditingDeltaInsertion(
            oldText: '',
            textInserted: 'n',
            insertionOffset: 0,
            selection: TextSelection.collapsed(offset: 1),
            composing: TextRange(start: 0, end: 1),
          ),
        ]);

        expect(preedit, ['n']);

        handler.updateEditingValueWithDeltas([
          const TextEditingDeltaReplacement(
            oldText: 'n',
            replacementText: 'ni',
            replacedRange: TextRange(start: 0, end: 1),
            selection: TextSelection.collapsed(offset: 2),
            composing: TextRange(start: 0, end: 2),
          ),
        ]);

        expect(preedit, ['n', 'ni']);
      });

      test('reports empty preedit text after commit', () {
        final preedit = <String>[];
        handler.onPreeditChanged = preedit.add;

        handler.updateEditingValueWithDeltas([
          const TextEditingDeltaInsertion(
            oldText: '',
            textInserted: 'a',
            insertionOffset: 0,
            selection: TextSelection.collapsed(offset: 1),
            composing: TextRange(start: 0, end: 1),
          ),
        ]);

        handler.updateEditingValueWithDeltas([
          const TextEditingDeltaReplacement(
            oldText: 'a',
            replacementText: 'A',
            replacedRange: TextRange(start: 0, end: 1),
            selection: TextSelection.collapsed(offset: 1),
            composing: TextRange.empty,
          ),
        ]);

        expect(preedit, ['a', '']);
      });

      test('commits non-composing replacement text', () {
        handler.updateEditingValueWithDeltas([
          const TextEditingDeltaInsertion(
            oldText: '',
            textInserted: 'ab',
            insertionOffset: 0,
            selection: TextSelection.collapsed(offset: 2),
            composing: TextRange.empty,
          ),
        ]);
        commits.clear();

        handler.updateEditingValueWithDeltas([
          const TextEditingDeltaReplacement(
            oldText: 'ab',
            replacementText: 'cd',
            replacedRange: TextRange(start: 0, end: 2),
            selection: TextSelection.collapsed(offset: 2),
            composing: TextRange.empty,
          ),
        ]);

        expect(commits, ['cd']);
      });

      test('ignores non-text updates', () {
        handler.updateEditingValueWithDeltas([
          const TextEditingDeltaNonTextUpdate(
            oldText: '',
            selection: TextSelection.collapsed(offset: 0),
            composing: TextRange.empty,
          ),
        ]);

        expect(commits, isEmpty);
        expect(deletes, isEmpty);
        expect(newlines, isEmpty);
      });
    });

    group('updateEditingValue', () {
      test('commits finalized composing text', () {
        final preedit = <String>[];
        handler.onPreeditChanged = preedit.add;

        handler.updateEditingValue(
          const TextEditingValue(
            text: ' ni',
            selection: TextSelection.collapsed(offset: 3),
            composing: TextRange(start: 1, end: 3),
          ),
        );

        expect(commits, isEmpty);
        expect(preedit, ['ni']);

        handler.updateEditingValue(
          const TextEditingValue(
            text: ' \u4f60',
            selection: TextSelection.collapsed(offset: 2),
          ),
        );

        expect(commits, ['\u4f60']);
        expect(preedit, ['ni', '']);
      });

      test('keeps platform text input attached after candidate commit', () {
        final calls = recordTextInputCalls();
        handler.attach();
        calls.clear();

        handler.updateEditingValue(
          const TextEditingValue(
            text: ' ni',
            selection: TextSelection.collapsed(offset: 3),
            composing: TextRange(start: 1, end: 3),
          ),
        );
        handler.updateEditingValue(
          const TextEditingValue(
            text: ' \u4f60',
            selection: TextSelection.collapsed(offset: 2),
          ),
        );

        expect(
          calls.where((call) => call.method == 'TextInput.clearClient'),
          isEmpty,
        );
        expect(calls.where((call) => call.method == 'TextInput.hide'), isEmpty);
      });

      test('strips sentinel from composing text', () {
        final preedit = <String>[];
        handler.onPreeditChanged = preedit.add;

        handler.updateEditingValue(
          const TextEditingValue(
            text: ' ni',
            selection: TextSelection.collapsed(offset: 3),
            composing: TextRange(start: 0, end: 3),
          ),
        );

        expect(preedit, ['ni']);
      });

      test('tracks sentinel-only composing range as active composition', () {
        final preedit = <String>[];
        handler.onPreeditChanged = preedit.add;

        handler.updateEditingValue(
          const TextEditingValue(
            text: ' ',
            selection: TextSelection.collapsed(offset: 1),
            composing: TextRange(start: 0, end: 1),
          ),
        );

        expect(handler.hasActiveComposition, isTrue);
        expect(preedit, isEmpty);
        expect(commits, isEmpty);
      });

      test(
        'preserves committed leading and trailing spaces after sentinel',
        () {
          handler.updateEditingValue(
            const TextEditingValue(
              text: '  a ',
              selection: TextSelection.collapsed(offset: 4),
            ),
          );

          expect(commits, [' a ']);
        },
      );
    });

    group('performAction', () {
      test('fires onNewline for newline action', () {
        handler.performAction(TextInputAction.newline);

        expect(newlines, hasLength(1));
      });
    });

    group('consumeCommittedCompositionEdit', () {
      test('returns true after a committed composition', () {
        handler.updateEditingValue(
          const TextEditingValue(
            text: ' ni',
            selection: TextSelection.collapsed(offset: 3),
            composing: TextRange(start: 1, end: 3),
          ),
        );
        handler.updateEditingValue(
          const TextEditingValue(
            text: ' \u4f60',
            selection: TextSelection.collapsed(offset: 2),
          ),
        );

        final consumed = handler.consumeCommittedCompositionEdit();

        expect(consumed, isTrue);
      });

      test('returns false before a composition commits', () {
        final consumed = handler.consumeCommittedCompositionEdit();

        expect(consumed, isFalse);
      });

      test('does not detach text input', () {
        final calls = recordTextInputCalls();
        handler.attach();
        handler.updateEditingValue(
          const TextEditingValue(
            text: ' \u4f60',
            selection: TextSelection.collapsed(offset: 2),
          ),
        );
        calls.clear();

        handler.consumeCommittedCompositionEdit();

        expect(
          calls.where((call) => call.method == 'TextInput.clearClient'),
          isEmpty,
        );
        expect(calls.where((call) => call.method == 'TextInput.hide'), isEmpty);
        expect(handler.isAttached, isTrue);
      });

      test('suppresses the next deletion delta', () {
        handler.updateEditingValue(
          const TextEditingValue(
            text: ' \u4f60',
            selection: TextSelection.collapsed(offset: 2),
          ),
        );
        handler.consumeCommittedCompositionEdit();

        handler.updateEditingValueWithDeltas([
          const TextEditingDeltaDeletion(
            oldText: '\u4f60',
            deletedRange: TextRange(start: 0, end: 1),
            selection: TextSelection.collapsed(offset: 0),
            composing: TextRange.empty,
          ),
        ]);

        expect(deletes, isEmpty);
      });

      test('suppresses only one deletion delta', () {
        handler.updateEditingValue(
          const TextEditingValue(
            text: ' \u4f60',
            selection: TextSelection.collapsed(offset: 2),
          ),
        );
        handler.consumeCommittedCompositionEdit();
        handler.updateEditingValueWithDeltas([
          const TextEditingDeltaDeletion(
            oldText: '\u4f60',
            deletedRange: TextRange(start: 0, end: 1),
            selection: TextSelection.collapsed(offset: 0),
            composing: TextRange.empty,
          ),
        ]);

        handler.updateEditingValueWithDeltas([
          const TextEditingDeltaDeletion(
            oldText: 'x',
            deletedRange: TextRange(start: 0, end: 1),
            selection: TextSelection.collapsed(offset: 0),
            composing: TextRange.empty,
          ),
        ]);

        expect(deletes, [1]);
      });

      test('expires suppression after a non-text delta', () {
        handler.updateEditingValue(
          const TextEditingValue(
            text: ' \u4f60',
            selection: TextSelection.collapsed(offset: 2),
          ),
        );
        handler.consumeCommittedCompositionEdit();
        handler.updateEditingValueWithDeltas([
          const TextEditingDeltaNonTextUpdate(
            oldText: ' ',
            selection: TextSelection.collapsed(offset: 1),
            composing: TextRange.empty,
          ),
        ]);

        handler.updateEditingValueWithDeltas([
          const TextEditingDeltaDeletion(
            oldText: 'x',
            deletedRange: TextRange(start: 0, end: 1),
            selection: TextSelection.collapsed(offset: 0),
            composing: TextRange.empty,
          ),
        ]);

        expect(deletes, [1]);
      });

      test(
        'suppresses deletion after a preceding non-text delta in same batch',
        () {
          handler.updateEditingValue(
            const TextEditingValue(
              text: ' \u4f60',
              selection: TextSelection.collapsed(offset: 2),
            ),
          );
          handler.consumeCommittedCompositionEdit();

          handler.updateEditingValueWithDeltas([
            const TextEditingDeltaNonTextUpdate(
              oldText: ' ',
              selection: TextSelection.collapsed(offset: 1),
              composing: TextRange.empty,
            ),
            const TextEditingDeltaDeletion(
              oldText: 'x',
              deletedRange: TextRange(start: 0, end: 1),
              selection: TextSelection.collapsed(offset: 0),
              composing: TextRange.empty,
            ),
          ]);

          expect(deletes, isEmpty);
        },
      );

      test('expires suppression after a no-op editing update', () {
        handler.updateEditingValue(
          const TextEditingValue(
            text: ' \u4f60',
            selection: TextSelection.collapsed(offset: 2),
          ),
        );
        handler.consumeCommittedCompositionEdit();
        handler.updateEditingValue(
          const TextEditingValue(
            text: ' ',
            selection: TextSelection.collapsed(offset: 1),
          ),
        );

        handler.updateEditingValueWithDeltas([
          const TextEditingDeltaDeletion(
            oldText: 'x',
            deletedRange: TextRange(start: 0, end: 1),
            selection: TextSelection.collapsed(offset: 0),
            composing: TextRange.empty,
          ),
        ]);

        expect(deletes, [1]);
      });

      test('keeps pending edit after an empty composing update', () {
        handler.updateEditingValue(
          const TextEditingValue(
            text: ' ni',
            selection: TextSelection.collapsed(offset: 3),
            composing: TextRange(start: 1, end: 3),
          ),
        );
        handler.updateEditingValue(
          const TextEditingValue(
            text: ' \u4f60',
            selection: TextSelection.collapsed(offset: 2),
          ),
        );
        handler.updateEditingValue(
          const TextEditingValue(
            text: ' ',
            selection: TextSelection.collapsed(offset: 1),
            composing: TextRange(start: 0, end: 1),
          ),
        );

        final consumed = handler.consumeCommittedCompositionEdit();

        expect(consumed, isTrue);
      });

      test('returns false after a canceled composition', () {
        handler.updateEditingValueWithDeltas([
          const TextEditingDeltaInsertion(
            oldText: '',
            textInserted: 'n',
            insertionOffset: 0,
            selection: TextSelection.collapsed(offset: 1),
            composing: TextRange(start: 0, end: 1),
          ),
        ]);
        handler.updateEditingValueWithDeltas([
          const TextEditingDeltaReplacement(
            oldText: 'n',
            replacementText: '',
            replacedRange: TextRange(start: 0, end: 1),
            selection: TextSelection.collapsed(offset: 0),
            composing: TextRange.empty,
          ),
        ]);

        final consumed = handler.consumeCommittedCompositionEdit();

        expect(consumed, isFalse);
      });
    });

    group('onFocusReceived', () {
      test('returns false', () {
        final acquiredFocus = handler.onFocusReceived();

        expect(acquiredFocus, isFalse);
      });
    });

    group('hide', () {
      test('clears preedit text', () {
        final preedit = <String>[];
        handler.onPreeditChanged = preedit.add;
        handler.updateEditingValue(
          const TextEditingValue(
            text: ' ni',
            selection: TextSelection.collapsed(offset: 3),
            composing: TextRange(start: 1, end: 3),
          ),
        );
        preedit.clear();

        handler.hide();

        expect(preedit, ['']);
      });
    });

    group('show', () {
      test('reuses an active connection', () {
        final calls = recordTextInputCalls();

        handler.show();
        handler.show();

        expect(textInputSetClientCalls(calls), hasLength(1));
      });
    });

    group('ensureAttached', () {
      test('attaches without showing the keyboard', () {
        final calls = recordTextInputCalls();

        handler.ensureAttached();

        expect(textInputSetClientCalls(calls), hasLength(1));
        expect(calls.where((call) => call.method == 'TextInput.show'), isEmpty);
      });

      test('reuses an active connection', () {
        final calls = recordTextInputCalls();

        handler.ensureAttached();
        handler.ensureAttached();

        expect(textInputSetClientCalls(calls), hasLength(1));
      });

      test('reopens a connection orphaned by another client', () {
        final calls = recordTextInputCalls();
        handler.attach();
        final other = TerminalInputClient()..viewId = 0;
        addTearDown(other.detach);
        other.attach();
        calls.clear();

        handler.ensureAttached();

        expect(textInputSetClientCalls(calls), hasLength(1));
      });

      test('clears visible preedit when reopening an orphaned connection', () {
        final preedit = <String>[];
        handler.onPreeditChanged = preedit.add;
        handler.attach();
        handler.updateEditingValue(
          const TextEditingValue(
            text: ' ni',
            selection: TextSelection.collapsed(offset: 3),
            composing: TextRange(start: 1, end: 3),
          ),
        );
        final other = TerminalInputClient()..viewId = 0;
        addTearDown(other.detach);
        other.attach();
        preedit.clear();

        handler.ensureAttached();

        expect(preedit, ['']);
      });
    });

    group('viewId', () {
      test('keeps the active connection when the view is unchanged', () {
        final calls = recordTextInputCalls();
        handler.attach();
        calls.clear();

        handler.viewId = 0;

        expect(calls, isEmpty);
      });

      test('replaces the active connection when the view changes', () {
        final calls = recordTextInputCalls();
        handler.attach();
        calls.clear();

        handler.viewId = 1;

        expect(calls.map((call) => call.method), [
          'TextInput.clearClient',
          'TextInput.setClient',
          'TextInput.setEditingState',
        ]);
      });

      test('uses the new view for the replacement connection', () {
        final calls = recordTextInputCalls();
        handler.attach();
        calls.clear();

        handler.viewId = 1;

        expect(textInputConfig(calls)['viewId'], 1);
      });
    });

    group('keyboardAppearance', () {
      test('updates the active config', () {
        final calls = recordTextInputCalls();
        handler.attach();
        calls.clear();

        handler.keyboardAppearance = Brightness.light;

        final config = textInputUpdateConfig(calls);
        expect(config['keyboardAppearance'], Brightness.light.toString());
      });
    });

    group('updateGeometry', () {
      test('reports active connection geometry', () {
        final calls = recordTextInputCalls();
        handler.attach();
        calls.clear();

        handler.updateGeometry(
          editableSize: const Size(80, 40),
          transform: Matrix4.identity()..translateByDouble(12.0, 24.0, 0, 1),
          caretRect: const Rect.fromLTWH(16, 18, 8, 18),
          composingRect: const Rect.fromLTWH(16, 18, 24, 18),
        );

        final editable = textInputCall(
          calls,
          'TextInput.setEditableSizeAndTransform',
        );
        expect(editable['width'], 80.0);
        expect(editable['height'], 40.0);
        expect(editable['transform'], hasLength(16));
        expect(textInputCall(calls, 'TextInput.setCaretRect'), {
          'x': 16.0,
          'y': 18.0,
          'width': 8.0,
          'height': 18.0,
        });
        expect(textInputCall(calls, 'TextInput.setMarkedTextRect'), {
          'x': 16.0,
          'y': 18.0,
          'width': 24.0,
          'height': 18.0,
        });
      });

      test('ignores detached connection geometry', () {
        final calls = recordTextInputCalls();

        handler.updateGeometry(
          editableSize: const Size(80, 40),
          transform: Matrix4.identity(),
          caretRect: const Rect.fromLTWH(16, 18, 8, 18),
          composingRect: const Rect.fromLTWH(16, 18, 24, 18),
        );

        expect(calls, isEmpty);
      });
    });

    group('attach', () {
      test('throws when no Flutter view is set', () {
        final client = TerminalInputClient();
        addTearDown(client.detach);

        expect(
          client.attach,
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'Text input requires an owning Flutter view before attachment.',
            ),
          ),
        );
      });

      test('replaces an existing connection', () {
        handler.attach();
        expect(handler.isAttached, isTrue);

        handler.attach(keyboardAppearance: Brightness.light);

        expect(handler.isAttached, isTrue);
      });

      test('uses terminal text input traits', () {
        final calls = recordTextInputCalls();

        handler.attach(keyboardAppearance: Brightness.light);

        final config = textInputConfig(calls);
        expect(config['autocorrect'], isFalse);
        expect(config['enableSuggestions'], isFalse);
        expect(
          config['smartDashesType'],
          SmartDashesType.disabled.index.toString(),
        );
        expect(
          config['smartQuotesType'],
          SmartQuotesType.disabled.index.toString(),
        );
        expect(config['enableInteractiveSelection'], isFalse);
        expect(
          config['textCapitalization'],
          TextCapitalization.none.toString(),
        );
        expect(config['enableIMEPersonalizedLearning'], isFalse);
        expect(config['enableInlinePrediction'], isFalse);
        expect(config['enableDeltaModel'], isTrue);
        expect(
          (config['inputType']! as Map<String, Object?>)['name'],
          'TextInputType.multiline',
        );
        expect(config['inputAction'], TextInputAction.newline.toString());
        expect(config['keyboardAppearance'], Brightness.light.toString());
        expect(config['autofill'], isNull);
      });
    });

    group('detach', () {
      test('clears the active connection', () {
        handler.attach();

        handler.detach();

        expect(handler.isAttached, isFalse);
      });
    });
  });
}

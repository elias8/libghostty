@Tags(['ffi'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flterm/src/controller/terminal_controller.dart';
import 'package:flterm/src/foundation.dart';
import 'package:flterm/src/view/view_attachment.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart'
    show Mods, RgbColor, Terminal, TerminalScreen;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ViewAttachment', () {
    late TerminalControllerImpl controller;
    late ViewAttachment attachment;

    setUp(() {
      controller = TerminalControllerImpl();
      attachment = ViewAttachment(controller);
    });

    tearDown(() {
      attachment.dispose();
      controller.dispose();
    });

    RgbColor rgb(Color color) => RgbColor(
      (color.r * 255).round().clamp(0, 255),
      (color.g * 255).round().clamp(0, 255),
      (color.b * 255).round().clamp(0, 255),
    );

    group('ownership', () {
      test('rejects a second active view attachment', () {
        expect(() => ViewAttachment(controller), throwsA(isA<StateError>()));
      });

      test('stale attachment disposal does not detach a newer view', () {
        final first = attachment;
        first.dispose();
        final second = ViewAttachment(controller);
        attachment = second;

        first.dispose();

        expect(() => ViewAttachment(controller), throwsA(isA<StateError>()));
      });
    });

    group('interaction state', () {
      test('starts without virtual modifiers', () {
        expect(attachment.virtualMods, const Mods.none());
      });

      test('projects only interaction changes', () {
        var notifications = 0;
        attachment.interaction.addListener(() => notifications++);

        controller.toggleMod(const Mods.ctrl());

        expect(notifications, 0);

        controller.write(Uint8List.fromList(utf8.encode('\x1b[?1049h')));

        expect(notifications, 1);
        expect(
          attachment.interaction.value.activeScreen,
          TerminalScreen.alternate,
        );
      });

      test('compares terminal modes by value', () {
        const first = ViewInteractionState(
          activeScreen: .primary,
          mouseTracking: .none,
          alternateScroll: false,
        );
        const second = ViewInteractionState(
          activeScreen: .primary,
          mouseTracking: .none,
          alternateScroll: false,
        );

        expect(first, second);
      });

      test('produces equal hashes for equal terminal modes', () {
        const first = ViewInteractionState(
          activeScreen: .primary,
          mouseTracking: .none,
          alternateScroll: false,
        );
        const second = ViewInteractionState(
          activeScreen: .primary,
          mouseTracking: .none,
          alternateScroll: false,
        );

        expect(first.hashCode, second.hashCode);
      });

      test('publishes broad changes without interaction notifications', () {
        var attachmentNotifications = 0;
        var interactionNotifications = 0;
        attachment.addListener(() => attachmentNotifications++);
        attachment.interaction.addListener(() => interactionNotifications++);

        controller.toggleMod(const Mods.ctrl());

        expect(attachmentNotifications, 1);
        expect(interactionNotifications, 0);
      });
    });

    group('applyTheme', () {
      void replaceWithRestored({bool preserveSnapshotColors = true}) {
        final source = Terminal(cols: 12, rows: 3)
          ..foreground = const RgbColor(12, 34, 56)
          ..background = const RgbColor(65, 43, 21);
        addTearDown(source.dispose);
        attachment.dispose();
        controller.dispose();
        controller =
            TerminalController.fromSnapshot(
                  source.encodeSnapshot(),
                  progressive: false,
                  preserveSnapshotColors: preserveSnapshotColors,
                )
                as TerminalControllerImpl;
        attachment = ViewAttachment(controller);
      }

      test('applies view colors to the terminal session', () {
        final theme = TerminalTheme.dark();

        attachment.applyTheme(theme);

        expect(attachment.terminal.foreground, rgb(theme.foreground));
        expect(attachment.terminal.background, rgb(theme.background));
        expect(attachment.terminal.palette[1], rgb(theme.palette[1]));
      });

      test('preserves snapshot colors on initial attachment', () {
        replaceWithRestored();

        attachment.applyTheme(TerminalTheme.dark(), initial: true);

        expect(
          (attachment.terminal.foreground, attachment.terminal.background),
          (const RgbColor(12, 34, 56), const RgbColor(65, 43, 21)),
        );
      });

      test('applies a later theme after preserving snapshot colors', () {
        replaceWithRestored();
        final theme = TerminalTheme.light();
        attachment.applyTheme(TerminalTheme.dark(), initial: true);

        attachment.applyTheme(theme);

        expect(
          (attachment.terminal.foreground, attachment.terminal.background),
          (rgb(theme.foreground), rgb(theme.background)),
        );
      });

      test('applies initial colors when preservation is disabled', () {
        replaceWithRestored(preserveSnapshotColors: false);
        final theme = TerminalTheme.dark();

        attachment.applyTheme(theme, initial: true);

        expect(
          (attachment.terminal.foreground, attachment.terminal.background),
          (rgb(theme.foreground), rgb(theme.background)),
        );
      });
    });

    group('handleViewportRowChanged', () {
      test('applies viewport row intents to the terminal session', () {
        controller.write(
          Uint8List.fromList(
            List.filled(40, 'scrollback row\r\n').join().codeUnits,
          ),
        );

        attachment.handleViewportRowChanged(0);

        expect(attachment.terminal.scrollbar.offset, 0);
      });
    });

    group('attach and detach', () {
      testWidgets('owns view services locally', (tester) async {
        final focusNode = _InspectableFocusNode();
        final scrollController = ScrollController();
        addTearDown(focusNode.dispose);
        addTearDown(scrollController.dispose);

        await tester.pumpWidget(
          Focus(focusNode: focusNode, child: const SizedBox()),
        );
        attachment.attach(focusNode, scrollController, viewId: 0);

        focusNode.requestFocus();
        await tester.pump();

        expect(focusNode.hasFocus, isTrue);

        attachment.detach();

        expect(attachment.input.preeditText, isEmpty);
      });

      testWidgets('does not duplicate a focus listener when reattached', (
        tester,
      ) async {
        final focusNode = _InspectableFocusNode();
        final scrollController = ScrollController();
        addTearDown(focusNode.dispose);
        addTearDown(scrollController.dispose);

        await tester.pumpWidget(
          Focus(focusNode: focusNode, child: const SizedBox()),
        );

        final initiallyHasListeners = focusNode.hasFocusListeners;
        attachment.attach(focusNode, scrollController, viewId: 0);
        final hasListenersAfterAttach = focusNode.hasFocusListeners;

        attachment.attach(focusNode, scrollController, viewId: 1);

        expect(focusNode.hasFocusListeners, hasListenersAfterAttach);
        attachment.detach();
        expect(focusNode.hasFocusListeners, initiallyHasListeners);
      });
    });

    group('dispose', () {
      test('leaves the application-owned controller usable', () {
        final output = <Uint8List>[];
        controller.onOutput = output.add;

        attachment.dispose();
        controller.sendText('ready');

        expect(utf8.decode(output.single), 'ready');
      });

      test('stops publishing controller changes', () {
        var notifications = 0;
        attachment.addListener(() => notifications++);

        attachment.dispose();
        controller.toggleMod(const Mods.ctrl());

        expect(notifications, 0);
      });
    });
  });
}

final class _InspectableFocusNode extends FocusNode {
  bool get hasFocusListeners => hasListeners;
}

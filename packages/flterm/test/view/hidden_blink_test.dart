import 'package:flterm/src/controller/terminal_controller.dart';
import 'package:flterm/src/foundation.dart';
import 'package:flterm/src/rendering.dart';
import 'package:flterm/src/view/terminal_view.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class FrameCountingBinding extends AutomatedTestWidgetsFlutterBinding {
  var frameRequests = 0;

  @override
  void scheduleFrame() {
    frameRequests++;
    super.scheduleFrame();
  }
}

void main() {
  final binding = FrameCountingBinding();

  testWidgets('retained terminal pauses blinking while ticker mode is muted', (
    tester,
  ) async {
    final controller = TerminalController(
      config: const TerminalConfig(cursorBlink: true),
    );
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    final enabled = ValueNotifier(true);
    addTearDown(enabled.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ValueListenableBuilder<bool>(
          valueListenable: enabled,
          builder: (context, value, child) =>
              TickerMode(enabled: value, child: child!),
          child: TerminalView(
            controller: controller,
            focusNode: focus,
            autofocus: true,
            showKeyboard: false,
            theme: TerminalTheme.dark().copyWith(
              cursor: const CursorTheme(
                blinkInterval: Duration(milliseconds: 10),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    bool cursorVisible() => tester
        .widget<TerminalRenderer>(find.byType(TerminalRenderer))
        .blinkVisible;
    expect(focus.hasFocus, true);
    expect(cursorVisible(), true);
    binding.frameRequests = 0;
    await tester.pump(const Duration(milliseconds: 10));
    expect(cursorVisible(), false);
    expect(binding.frameRequests, greaterThan(0));

    enabled.value = false;
    await tester.pump();
    await tester.pump();
    binding.frameRequests = 0;
    await tester.pump(const Duration(milliseconds: 30));
    expect(focus.hasFocus, true);
    expect(
      binding.frameRequests,
      0,
      reason: 'muted cursor must not wake frames',
    );
    expect(cursorVisible(), true);

    focus.unfocus();
    await tester.pump();
    focus.requestFocus();
    await tester.pump();
    binding.frameRequests = 0;
    await tester.pump(const Duration(milliseconds: 30));
    expect(focus.hasFocus, true);
    expect(binding.frameRequests, 0);
    expect(cursorVisible(), true);

    enabled.value = true;
    await tester.pump();
    await tester.pump();
    binding.frameRequests = 0;
    await tester.pump(const Duration(milliseconds: 10));
    expect(cursorVisible(), false);
    expect(binding.frameRequests, greaterThan(0));
    await tester.pumpWidget(const SizedBox());
  });
}

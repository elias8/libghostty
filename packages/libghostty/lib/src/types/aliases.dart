import 'dart:typed_data';

import '../generated/libghostty_enums.g.dart';
import 'terminal.dart';

/// Width behavior of a terminal cell.
typedef CellWidth = CellWide;

/// Visual style reported by a render-state cursor snapshot.
typedef CursorShape = RenderStateCursorVisualStyle;

/// Cursor style accepted by terminal configuration APIs.
typedef TerminalCursorShape = TerminalCursorStyle;

/// Mouse tracking mode exposed by the terminal API.
typedef MouseTracking = MouseTrackingMode;

/// Semantic cell content classification.
typedef SemanticContent = CellSemanticContent;

/// Semantic prompt state reported for a row.
typedef SemanticPrompt = RowSemanticPrompt;

/// Underline style used by SGR attributes.
typedef UnderlineStyle = SgrUnderline;

typedef ValueGetter<T> = T Function();
typedef ValueSetter<T> = void Function(T value);
typedef VoidCallback = void Function();

/// Accepts one Dart-owned continuation chunk and returns whether it was fully
/// consumed. Returning false aborts the operation with an I/O error.
typedef ContinuationWriter = bool Function(Uint8List data);

/// Handles an atomic clipboard write requested synchronously by terminal
/// content. The result answers protocols with write acknowledgements and is
/// ignored by protocols without them, including OSC 52 and iTerm2 OSC 1337
/// Copy.
typedef ClipboardWriteCallback =
    ClipboardWriteResult Function(ClipboardWrite write);

/// Handles a synchronous clipboard read requested by terminal content.
typedef ClipboardReadCallback =
    ClipboardReadReply Function(ClipboardReadRequest read);

/// Supplies cryptographically secure random bytes to libghostty.
typedef SysRandomSecureCallback = bool Function(Uint8List buffer);

/// Handles a desktop notification requested synchronously by terminal content.
typedef DesktopNotificationCallback = void Function(DesktopNotification value);

/// Handles a progress report requested synchronously by terminal content.
typedef TerminalProgressCallback = void Function(TerminalProgress value);
typedef TerminalProgramStatusCallback = ValueSetter<TerminalProgramStatus>;
typedef TerminalSemanticPromptCallback = ValueSetter<TerminalSemanticPrompt>;

/// Handles an unsupported terminal string sequence synchronously.
typedef TerminalUnknownSequenceCallback = ValueSetter<TerminalUnknownSequence>;

/// Callback invoked for each internal libghostty log message.
///
/// Scope and message bytes are decoded and copied before invocation.
typedef SysLogCallback =
    void Function(SysLogLevel level, String scope, String message);

/// Callback that decodes PNG bytes to RGBA pixels.
///
/// Returning null rejects the image. The input bytes are Dart-owned, and the
/// returned pixel bytes are copied before the callback returns.
typedef PngDecoder = DecodedImage? Function(Uint8List pngBytes);

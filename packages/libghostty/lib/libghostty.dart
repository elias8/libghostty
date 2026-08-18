/// Framework-independent terminal emulation powered by libghostty.
///
/// The package exposes idiomatic Dart values and resource types over the
/// libghostty C ABI. Native applications load libghostty through package build
/// hooks. Web applications must call [initializeForWeb] with a compatible Wasm
/// artifact before constructing resources.
///
/// Dispose owned resources such as [Terminal], [RenderState], and encoders when
/// they are no longer needed. Borrowed views, including [GridRef] and
/// [KittyImage], must be reacquired after a terminal mutation invalidates them.
///
/// ```dart
/// import 'package:libghostty/libghostty.dart';
/// ```
library;

export 'src/api/build_info.dart' show LibGhosttyBuildInfo;
export 'src/api/color.dart'
    show
        colorContrast,
        colorLuminance,
        colorPerceivedLuminance,
        defaultColorPalette,
        generateColorPalette,
        parseColor,
        parsePaletteEntry,
        parseX11ColorName,
        x11ColorNames;
export 'src/api/encode.dart'
    show ColorSchemeReportEncode, FocusEventEncode, SizeReportStyleEncode;
export 'src/api/key/kitty_key_flags.dart' show KittyKeyFlags;
export 'src/api/key/mods.dart' show Mods;
export 'src/api/osc_parser.dart' show OscCommand, OscParser;
export 'src/api/paste.dart' show pasteEncode, pasteIsSafe;
export 'src/api/sgr_parser.dart' show SgrParser;
export 'src/api/sys.dart' show LibGhostty, LogCallback;
export 'src/api/terminal/terminal.dart'
    show
        CellIterator,
        DirtyState,
        Formatter,
        GridRef,
        KeyEncoder,
        KeyEvent,
        KittyGraphics,
        KittyImage,
        MouseEncoder,
        MouseEvent,
        RenderState,
        RowIterator,
        RowSelectionRange,
        Selection,
        SelectionGesture,
        SelectionGestureBehaviors,
        SelectionGestureEvent,
        SelectionGestureGeometry,
        SelectionGestureState,
        Terminal,
        TrackedGridRef;
export 'src/api/terminal/terminal_mode.dart' show TerminalMode;
export 'src/api/unicode.dart' show unicodeCodepointWidth, unicodeGraphemeWidth;
export 'src/bindings/bindings.dart' show initializeForWeb;
export 'src/generated/libghostty_enums.g.dart'
    show
        ClipboardLocation,
        ClipboardWriteResult,
        ColorScheme,
        FocusEvent,
        FormatterFormat,
        Key,
        KeyAction,
        KittyImageCompression,
        KittyImageFormat,
        KittyPlacementLayer,
        ModeReportState,
        MouseAction,
        MouseButton,
        OptionAsAlt,
        OscCommandType,
        PointTag,
        SelectionAdjust,
        SelectionGestureAutoscroll,
        SelectionGestureBehavior,
        SelectionOrder,
        SgrAttributeTag,
        SizeReportStyle,
        SysLogLevel,
        TerminalCompressionMode,
        TerminalCompressionResult,
        TerminalProgressState,
        TerminalScreen,
        TerminalUnknownSequenceTag;
export 'src/listenable.dart' show Listenable;
export 'src/types/aliases.dart'
    show
        ClipboardWriteCallback,
        ContinuationWriter,
        DesktopNotificationCallback,
        PngDecoder,
        SysLogCallback,
        TerminalCursorShape,
        TerminalProgressCallback,
        TerminalUnknownSequenceCallback,
        ValueGetter,
        ValueSetter,
        VoidCallback;
export 'src/types/types.dart'
    show
        CellColor,
        CellWidth,
        ClipboardContent,
        ClipboardWrite,
        CursorShape,
        DecodedImage,
        DefaultColor,
        DesktopNotification,
        DeviceAttributesPrimary,
        DeviceAttributesResponse,
        DeviceAttributesSecondary,
        DeviceAttributesTertiary,
        FormatterExtra,
        InvalidValueException,
        IoException,
        KittyPlacement,
        KittyPlacementRenderInfo,
        KittyUnicodePlacement,
        KittyUnicodePlacementRenderInfo,
        LibGhosttyException,
        LimitExceededException,
        MouseEncoderSize,
        MouseFormat,
        MouseTracking,
        NamedColor,
        NoValueException,
        OptimizeMode,
        OutOfMemoryException,
        OutOfSpaceException,
        PaletteColor,
        Position,
        RenderStateCursor,
        RgbColor,
        Scrollbar,
        SemanticContent,
        SemanticPrompt,
        SgrAttribute,
        Style,
        TerminalColors,
        TerminalGeometry,
        TerminalProgress,
        TerminalSizeInfo,
        TerminalUnknownSequence,
        UnderlineStyle,
        UnknownResultException,
        X11ColorName;

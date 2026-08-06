/// Terminal emulation powered by libghostty.
///
/// ```dart
/// import 'package:libghostty/libghostty.dart';
/// ```
library;

export 'src/bindings/bindings.dart' show initializeForWeb;
export 'src/bindings/types/aliases.dart'
    show
        ClipboardContent,
        ClipboardWrite,
        ClipboardWriteCallback,
        DecodedImage,
        DesktopNotification,
        DesktopNotificationCallback,
        PngDecoder,
        TerminalGeometry,
        TerminalProgress,
        TerminalProgressCallback,
        X11ColorName;
export 'src/bindings/types/types.dart'
    show
        CellColor,
        CellWidth,
        CursorShape,
        DefaultColor,
        DeviceAttributesPrimary,
        DeviceAttributesResponse,
        DeviceAttributesSecondary,
        DeviceAttributesTertiary,
        FormatterExtra,
        InvalidValueException,
        LibGhosttyException,
        MouseEncoderSize,
        MouseFormat,
        MouseTracking,
        NamedColor,
        OptimizeMode,
        OutOfMemoryException,
        PaletteColor,
        Position,
        RgbColor,
        Scrollbar,
        SemanticContent,
        SemanticPrompt,
        SgrAttribute,
        Style,
        TerminalColors,
        TerminalSizeInfo,
        UnderlineStyle;
export 'src/ffi/libghostty_enums.g.dart'
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
        SelectionGestureEventOption,
        SelectionOrder,
        SgrAttributeTag,
        SizeReportStyle,
        SysLogLevel,
        TerminalCompressionMode,
        TerminalCompressionResult,
        TerminalProgressState,
        TerminalScreen;
export 'src/impl/build_info.dart' show LibGhosttyBuildInfo;
export 'src/impl/color.dart'
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
export 'src/impl/encode.dart'
    show ColorSchemeReportEncode, FocusEventEncode, SizeReportStyleEncode;
export 'src/impl/key/kitty_key_flags.dart' show KittyKeyFlags;
export 'src/impl/key/mods.dart' show Mods;
export 'src/impl/osc_parser.dart' show OscCommand, OscParser;
export 'src/impl/paste.dart' show pasteEncode, pasteIsSafe;
export 'src/impl/sgr_parser.dart' show SgrParser;
export 'src/impl/sys.dart' show LibGhostty, LogCallback;
export 'src/impl/terminal/terminal.dart'
    show
        CellIterator,
        Cursor,
        DirtyState,
        Formatter,
        GridRef,
        KeyEncoder,
        KeyEvent,
        KittyGraphics,
        KittyImage,
        MouseEncoder,
        MouseEvent,
        Placement,
        RenderInfo,
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
export 'src/impl/terminal/terminal_mode.dart' show TerminalMode;
export 'src/impl/unicode.dart' show unicodeCodepointWidth, unicodeGraphemeWidth;
export 'src/listenable.dart' show Listenable;

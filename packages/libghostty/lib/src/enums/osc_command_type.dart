/// OSC (Operating System Command) sequence types.
///
/// Identifies the type of an OSC escape sequence parsed from terminal
/// output.
///
/// ```dart
/// final command = parser.next();
/// if (command.type == OscCommandType.changeWindowTitle) {
///   print('new title: ${command.data}');
/// }
/// ```
// Maps 1:1 with the native GhosttyOscCommandType enum.
enum OscCommandType {
  invalid,
  changeWindowTitle,
  changeWindowIcon,
  semanticPrompt,
  clipboardContents,
  reportPwd,
  mouseShape,
  colorOperation,
  kittyColorProtocol,
  showDesktopNotification,
  hyperlinkStart,
  hyperlinkEnd,
  conemuSleep,
  conemuShowMessageBox,
  conemuChangeTabTitle,
  conemuProgressReport,
  conemuWaitInput,
  conemuGuimacro,
  conemuRunProcess,
  conemuOutputEnvironmentVariable,
  conemuXtermEmulation,
  conemuComment,
  kittyTextSizing;

  static OscCommandType fromNative(int value) {
    if (value >= 0 && value < OscCommandType.values.length) {
      return OscCommandType.values[value];
    }
    return OscCommandType.invalid;
  }
}

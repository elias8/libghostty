import '../bindings/bindings.dart';
import '../types/aliases.dart';

/// Callback invoked by libghostty to emit an internal log message.
///
/// Messages originate from the native library's Zig side and cover events
/// like unknown control sequences, kitty graphics decoding errors, and
/// other diagnostics. The debug level is only emitted by debug builds of
/// the native library; release builds compile those calls out entirely.
///
/// Byte slices received from the C ABI are already decoded into Dart
/// strings before this callback runs. Native log delivery may originate on any
/// thread and is dispatched asynchronously to the isolate that registered the
/// callback. A queued message is delivered to whichever logger is installed
/// when it reaches the Dart event loop. User errors are reported through that
/// registration zone's uncaught error handler.
typedef LogCallback = SysLogCallback;

/// Process-global configuration hooks for the native libghostty library.
///
/// These settings are installed once at startup and affect every
/// [Terminal] instance in the process. Install them before creating any
/// terminal that relies on them.
///
/// ```dart
/// void main() {
///   LibGhostty.setLogger((level, scope, message) {
///     debugPrint('[$level]$scope: $message');
///   });
///   runApp(const MyApp());
/// }
/// ```
abstract final class LibGhostty {
  /// Full version of the loaded library, including any pre-release or build
  /// suffix.
  static String get version => bindings.utility.version();

  /// Clears the installed logger and stops delivering messages to Dart.
  ///
  /// Safe to call multiple times. The process-global native transport remains
  /// alive so a native thread cannot call a closed function pointer. After
  /// this, log output is silently discarded until another logger is installed.
  static void clearLogger() => bindings.system.sysClearLogCallback();

  /// Clears the installed PNG decoder.
  ///
  /// Safe to call multiple times. After this, PNG payloads are
  /// rejected until another decoder is installed. On WebAssembly, the
  /// callback-table slot is released after the C option is cleared. Native
  /// keeps its callback trampoline alive for the binding lifetime because the
  /// C ABI does not provide a quiescence operation for in-flight callbacks.
  static void clearPngDecoder() => bindings.system.sysClearPngDecoder();

  /// Restores the platform-provided secure random source.
  static void clearRandomSecure() => bindings.system.sysClearRandomSecure();

  /// Installs [logger] as the sink for internal libghostty log messages.
  ///
  /// Replaces any previously installed logger (including the one set by
  /// [useStderrLogger]). Use [clearLogger] to stop receiving log messages;
  /// with no logger installed, log output is silently discarded.
  static void setLogger(LogCallback logger) {
    bindings.system.sysSetLogCallback(logger);
  }

  /// Installs [decoder] as the PNG decoder invoked by libghostty when a
  /// Kitty graphics payload arrives in PNG form.
  ///
  /// Replaces any previously installed decoder. Use [clearPngDecoder]
  /// to stop accepting PNG payloads; with no decoder installed, PNG
  /// data is rejected by the native library and no image is stored.
  /// The callback returns null to signal a decode failure, which is
  /// treated the same as having no decoder installed for that payload.
  ///
  /// The `DecodedImage.rgba` buffer is copied into a library-owned
  /// allocation before the callback returns, so the caller's buffer
  /// lifetime is not a concern. PNG decoding runs synchronously on the thread
  /// that is processing the terminal operation. Serialize decoder
  /// registration, terminal use, and decoder clearing with that operation.
  ///
  /// ```dart
  /// LibGhostty.setPngDecoder((pngBytes) {
  ///   final decoded = decodePngToRgba(pngBytes);
  ///   if (decoded == null) return null;
  ///   return DecodedImage(
  ///     width: decoded.w,
  ///     height: decoded.h,
  ///     rgba: decoded.pixels,
  ///   );
  /// });
  /// ```
  static void setPngDecoder(PngDecoder decoder) =>
      bindings.system.sysSetPngDecoder(decoder);

  /// Installs [callback] as libghostty's cryptographically secure random
  /// source. The callback must fill the supplied buffer completely.
  static void setRandomSecure(SysRandomSecureCallback callback) {
    bindings.system.sysSetRandomSecure(callback);
  }

  /// Installs the native library's built-in stderr log sink.
  ///
  /// Each message is formatted as `[level](scope): message` and written
  /// to stderr. Equivalent to registering a logger that delegates to
  /// `ghostty_sys_log_stderr`. Replaces any previously installed logger.
  static void useStderrLogger() => bindings.system.sysSetLogToStderr();
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../generated/libghostty_enums.g.dart';

/// Supplies the requested MIME representation synchronously.
///
/// Write chunks through [sink] and return true when complete. Return false
/// when the representation cannot be read. The sink expires when this callback
/// returns. A refused write fails the paste even if the callback returns true.
/// Returning false causes an IoException from Terminal.paste. It does not
/// produce a false paste result.
typedef PasteReader = bool Function(String mime, PasteSink sink);

/// A borrowed destination valid only during one [PasteReader] callback.
abstract interface class PasteSink {
  /// Consumes [bytes] synchronously. Returns whether all bytes were accepted.
  ///
  /// Stop writing after false. Writing after the reader returns throws
  /// [StateError], including an empty write.
  bool write(Uint8List bytes);
}

/// A paste request interpreted according to the terminal's current modes.
@immutable
sealed class PasteRequest {
  /// Whether text that can inject commands has been approved by the caller.
  final bool allowUnsafe;

  /// Advertises ordered MIME representations without reading their payloads.
  ///
  /// [source] preserves whether the input came from a clipboard or direct
  /// insertion. [location] applies to clipboard input. MIME spelling, order,
  /// and duplicates are preserved. The MIME list is copied, but payloads are
  /// requested lazily through [read].
  ///
  /// Kitty paste events can advertise non-text representations without calling
  /// [read]. Subsequent protocol reads use Terminal.onClipboardRead. The
  /// request and its reader do not become persistent clipboard storage.
  factory PasteRequest.mime({
    required PasteSource source,
    ClipboardLocation location,
    required List<String> mimes,
    required PasteReader read,
    bool allowUnsafe,
  }) = MimePaste._;

  /// Encodes direct text once into an owned, read-only UTF-8 representation.
  ///
  /// This represents IME, drop, or scripted input. For clipboard-origin text,
  /// use [PasteRequest.mime] with [PasteSource.clipboard].
  factory PasteRequest.text(String text, {bool allowUnsafe}) = TextPaste._;

  const PasteRequest._({required this.allowUnsafe});
}

/// Lazy MIME representations with their actual input provenance.
@immutable
final class MimePaste extends PasteRequest {
  /// Why the input was supplied.
  final PasteSource source;

  /// Clipboard location. Ignored for direct text input.
  final ClipboardLocation location;

  /// Ordered, immutable advertised MIME names.
  final List<String> mimes;

  /// Supplies only the representation requested by the terminal.
  final PasteReader read;

  MimePaste._({
    required this.source,
    this.location = .standard,
    required List<String> mimes,
    required this.read,
    super.allowUnsafe = false,
  }) : mimes = List.unmodifiable(mimes),
       super._();
}

/// An owned UTF-8 text representation supplied directly to the terminal.
@immutable
final class TextPaste extends PasteRequest {
  /// Read-only UTF-8 bytes owned by this request.
  final Uint8List data;

  TextPaste._(String text, {super.allowUnsafe = false})
    : data = utf8.encode(text).asUnmodifiableView(),
      super._();
}

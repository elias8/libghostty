import 'package:meta/meta.dart';

/// Kitty keyboard protocol mode flags.
///
/// Bitflags controlling the progressive enhancement modes of the Kitty
/// keyboard protocol.
///
/// ```dart
/// final flags = KittyKeyFlags.disambiguate | KittyKeyFlags.reportEvents;
/// print(flags.isDisabled); // false
/// ```
// Wraps the native GhosttyKittyKeyFlags type.
@immutable
final class KittyKeyFlags {
  static const disabled = KittyKeyFlags(0);
  static const disambiguate = KittyKeyFlags(1 << 0);
  static const reportEvents = KittyKeyFlags(1 << 1);
  static const reportAlternates = KittyKeyFlags(1 << 2);
  static const reportAll = KittyKeyFlags(1 << 3);
  static const reportAssociated = KittyKeyFlags(1 << 4);
  static const all = KittyKeyFlags(0x1F);

  final int value;

  const KittyKeyFlags(this.value);

  @override
  int get hashCode => value.hashCode;

  bool get isDisabled => value == 0;

  @override
  bool operator ==(Object other) =>
      other is KittyKeyFlags && other.value == value;

  @override
  String toString() => 'KittyKeyFlags(0x${value.toRadixString(16)})';

  KittyKeyFlags operator |(KittyKeyFlags other) =>
      KittyKeyFlags(value | other.value);
}

import 'package:meta/meta.dart';

/// Keyboard modifier key flags.
///
/// A bitmask representing active keyboard modifiers. Supports bitwise
/// combination and individual flag testing.
///
/// Side bits indicate which physical key is pressed when a modifier is
/// active. A set side bit means the right-side key; unset means left
/// (or unknown). Side bits are only meaningful when the corresponding
/// modifier bit is also set.
///
/// ```dart
/// final mods = Mods.ctrl | Mods.shift;
/// print(mods.hasCtrl);  // true
/// print(mods.hasShift); // true
/// print(mods.hasAlt);   // false
/// ```
// Wraps the native GhosttyMods type.
@immutable
final class Mods {
  static const none = Mods(0);
  static const shift = Mods(1 << 0);
  static const ctrl = Mods(1 << 1);
  static const alt = Mods(1 << 2);
  static const superKey = Mods(1 << 3);
  static const capsLock = Mods(1 << 4);
  static const numLock = Mods(1 << 5);
  static const shiftSide = Mods(1 << 6);
  static const ctrlSide = Mods(1 << 7);
  static const altSide = Mods(1 << 8);
  static const superSide = Mods(1 << 9);

  final int value;

  const Mods(this.value);

  bool get hasAlt => value & alt.value != 0;

  bool get hasCapsLock => value & capsLock.value != 0;

  bool get hasCtrl => value & ctrl.value != 0;

  @override
  int get hashCode => value.hashCode;

  bool get hasNumLock => value & numLock.value != 0;

  bool get hasShift => value & shift.value != 0;

  bool get hasSuper => value & superKey.value != 0;

  bool get isAltRight => value & altSide.value != 0;

  bool get isCtrlRight => value & ctrlSide.value != 0;

  bool get isEmpty => value == 0;

  bool get isShiftRight => value & shiftSide.value != 0;

  bool get isSuperRight => value & superSide.value != 0;

  /// Returns the flags present in both operands.
  ///
  /// ```dart
  /// final mods = Mods.ctrl | Mods.shift | Mods.alt;
  /// final filtered = mods & Mods.ctrl;
  /// print(filtered.hasCtrl); // true
  /// print(filtered.hasAlt);  // false
  /// ```
  Mods operator &(Mods other) => Mods(value & other.value);

  @override
  bool operator ==(Object other) => other is Mods && other.value == value;

  @override
  String toString() {
    if (isEmpty) return 'Mods.none';
    final parts = <String>[];
    if (hasShift) parts.add(isShiftRight ? 'shiftRight' : 'shift');
    if (hasCtrl) parts.add(isCtrlRight ? 'ctrlRight' : 'ctrl');
    if (hasAlt) parts.add(isAltRight ? 'altRight' : 'alt');
    if (hasSuper) parts.add(isSuperRight ? 'superRight' : 'super');
    if (hasCapsLock) parts.add('capsLock');
    if (hasNumLock) parts.add('numLock');
    return 'Mods(${parts.join(' | ')})';
  }

  /// Combines the flags from both operands.
  ///
  /// ```dart
  /// final mods = Mods.ctrl | Mods.shift;
  /// print(mods.hasCtrl);  // true
  /// print(mods.hasShift); // true
  /// ```
  Mods operator |(Mods other) => Mods(value | other.value);
}

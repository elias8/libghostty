import 'dart:js_interop';

extension type RawCell(JSBigInt value) {
  factory RawCell.fromOpaque(Object value) => RawCell(value as JSBigInt);

  Object get opaque => value;
}
extension type RawRow(JSBigInt value) {
  factory RawRow.fromOpaque(Object value) => RawRow(value as JSBigInt);

  Object get opaque => value;
}

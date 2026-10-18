extension type const RawCell(int value) {
  factory RawCell.fromOpaque(Object value) => RawCell(value as int);

  Object get opaque => value;
}
extension type const RawRow(int value) {
  factory RawRow.fromOpaque(Object value) => RawRow(value as int);

  Object get opaque => value;
}

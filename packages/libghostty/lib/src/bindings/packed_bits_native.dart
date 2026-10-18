@pragma('vm:prefer-inline')
int extract(int raw, int shift, int divisor, int modulus) =>
    (raw >>> shift) & (modulus - 1);

final class PackedBit {
  final int lsb;
  final int width;
  final int divisor;
  final int modulus;

  PackedBit({required this.lsb, required this.width})
    : divisor = _powerOfTwo(lsb),
      modulus = _powerOfTwo(width);
}

int extractWords(int lo, int hi, PackedBit bit) {
  final raw = lo | (hi << 32);
  return extract(raw, bit.lsb, bit.divisor, bit.modulus);
}

int _powerOfTwo(int exponent) {
  var value = 1;
  for (var i = 0; i < exponent; i++) {
    value *= 2;
  }
  return value;
}

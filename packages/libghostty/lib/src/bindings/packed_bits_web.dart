int extract(int raw, int shift, int divisor, int modulus) =>
    raw ~/ (shift < 32 ? divisor : divisor * 0x100000000) % modulus;

final class PackedBit {
  final int lsb;
  final int width;
  final int divisor;
  final int modulus;

  PackedBit({required this.lsb, required this.width})
    : divisor = _powerOfTwo(lsb % 32),
      modulus = _powerOfTwo(width);
}

int extractWords(int lo, int hi, PackedBit bit) {
  if (bit.width <= 32) {
    final word = bit.lsb >= 32
        ? hi >>> (bit.lsb - 32)
        : bit.lsb + bit.width <= 32
        ? lo >>> bit.lsb
        : (lo >>> bit.lsb) | (hi << (32 - bit.lsb));
    return (word & (bit.modulus - 1)) >>> 0;
  }
  if (bit.lsb >= 32) return hi ~/ bit.divisor % bit.modulus;
  if (bit.lsb + bit.width <= 32) return lo ~/ bit.divisor % bit.modulus;
  final lowModulus = 0x100000000 ~/ bit.divisor;
  final low = lo ~/ bit.divisor;
  final high = hi % (bit.modulus ~/ lowModulus);
  return low + high * lowModulus;
}

int _powerOfTwo(int exponent) {
  var value = 1;
  for (var i = 0; i < exponent; i++) {
    value *= 2;
  }
  return value;
}

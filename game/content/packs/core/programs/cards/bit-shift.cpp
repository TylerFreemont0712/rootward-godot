Bolts bit_shift(Bolts bolts, const Battle& battle) {
  // x << 1 slides every bit one place left: it doubles x. Keeping only the low bits (& 31) is overflow: past the
  // top the value wraps around to the bottom.
  for (Bolt& bolt : bolts) bolt.power = static_cast<int>((static_cast<unsigned int>(bolt.power) << 1) & 31u);
  return bolts;
}

function bitShift(bolts, battle) {
  // x << 1 slides every bit one place left: it doubles x. Keeping only the low bits (& 31) is overflow: past the
  // top the value wraps around to the bottom.
  return bolts.map((bolt) => ({ ...bolt, power: (bolt.power << 1) & 31 }));
}

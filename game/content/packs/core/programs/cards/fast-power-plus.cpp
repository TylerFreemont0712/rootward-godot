Bolts fast_power_plus(Bolts bolts, const Battle& battle) {
  // Exponentiation by squaring: 2 ** k in about log2(k) multiplications, not k. Square the base every round and
  // multiply it into the answer whenever the matching bit of k is set. Here k = 4: the strongest bolt
  // (the first, if two tie) is doubled four times.
  if (bolts.empty()) return bolts;
  long long factor = 1;
  long long base = 2;
  int k = 4;
  while (k > 0) {
    if (k & 1) factor *= base;
    base *= base;
    k >>= 1;
  }
  int strongest = 0;
  for (int i = 1; i < static_cast<int>(bolts.size()); i++) {
    if (bolts[i].power > bolts[strongest].power) strongest = i;
  }
  bolts[strongest].power = static_cast<int>(bolts[strongest].power * factor);
  return bolts;
}

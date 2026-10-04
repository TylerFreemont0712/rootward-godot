function fastPowerPlus(bolts, battle) {
  // Exponentiation by squaring: 2 ** k in about log2(k) multiplications, not k. Square the base every round and
  // multiply it into the answer whenever the matching bit of k is set. Here k = 4: the strongest bolt
  // (the first, if two tie) is doubled four times.
  if (bolts.length === 0) return bolts;
  let factor = 1;
  let base = 2;
  let k = 4;
  while (k > 0) {
    if (k & 1) factor *= base;
    base *= base;
    k >>= 1;
  }
  let strongest = 0;
  for (let i = 0; i < bolts.length; i++) {
    if (bolts[i].power > bolts[strongest].power) strongest = i;
  }
  return bolts.map((bolt, i) => (i === strongest ? { ...bolt, power: bolt.power * factor } : bolt));
}

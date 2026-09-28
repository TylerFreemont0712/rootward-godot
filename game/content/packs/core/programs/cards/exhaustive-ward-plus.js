function exhaustiveWardPlus(bolts, battle) {
  // Every subset of the first ten bolts as a bitmask (2^n of them): keep the one whose total reaches 16 with the
  // least to spare. Those become your block; the rest still fly. If none reaches 16, all ten guard.
  const pool = bolts.slice(0, 10);
  let best = -1;
  let bestTotal = -1;
  for (let mask = 1; mask < 1 << pool.length; mask++) {
    let total = 0;
    for (let i = 0; i < pool.length; i++) if ((mask >> i) & 1) total += pool[i].power;
    if (total >= 16 && (bestTotal < 0 || total < bestTotal)) {
      best = mask;
      bestTotal = total;
    }
  }
  if (best < 0) best = (1 << pool.length) - 1;
  return bolts.map((bolt, i) => (i < pool.length && (best >> i) & 1 ? { ...bolt, block: true } : { ...bolt }));
}

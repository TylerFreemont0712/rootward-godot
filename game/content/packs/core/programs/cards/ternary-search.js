function ternarySearch(bolts, battle) {
  // Ternary search: on a volley that rises then falls, compare the two third-points and throw away the third that cannot hold the peak. O(log n).
  // The peak bolt doubles.
  if (bolts.length === 0) return bolts;
  let lo = 0;
  let hi = bolts.length - 1;
  while (hi - lo > 2) {
    const third = Math.floor((hi - lo) / 3);
    const m1 = lo + third;
    const m2 = hi - third;
    if (bolts[m1].power < bolts[m2].power) lo = m1 + 1;
    else hi = m2 - 1;
  }
  let peak = lo;
  for (let i = lo + 1; i <= hi; i++) {
    if (bolts[i].power > bolts[peak].power) peak = i;
  }
  const result = bolts.map((bolt) => ({ ...bolt }));
  result[peak].power *= 2;
  return result;
}

function binary_pick(bolts, battle) {
  let lo = 0, hi = bolts.length;
  while (lo < hi) {
    const mid = Math.floor((lo + hi) / 2);
    if (bolts[mid].power < 8) lo = mid + 1; else hi = mid;
  }
  return lo < bolts.length ? [{ ...bolts[lo], power: bolts[lo].power + 3 }] : [];
}

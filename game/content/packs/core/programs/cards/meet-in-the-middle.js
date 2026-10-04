function meetInTheMiddle(bolts, battle) {
  // Meet in the middle: Exhaustive Kill tries all 2^n subsets. Split the bolts in two halves instead, list every
  // subset sum of each (2^(n/2) each), sort one list, and binary-search it for the partner of every sum of the other.
  // It finds the same subset, the smallest total that kills the front foe, with the square root of the work.
  const foes = battle.foes || [];
  if (foes.length === 0 || bolts.length === 0) return bolts;
  const need = foes[0].hp + (foes[0].shield || 0);
  const pool = bolts.slice(0, 12);
  const half = Math.floor(pool.length / 2);
  function sums(items, shift) {
    const found = [[0, 0]];
    for (let k = 0; k < items.length; k++) {
      const size = found.length;
      for (let n = 0; n < size; n++) {
        found.push([found[n][0] + items[k].power, found[n][1] | (1 << (shift + k))]);
      }
    }
    return found;
  }
  const low = sums(pool.slice(0, half), 0);
  const high = sums(pool.slice(half), half).sort((a, b) => a[0] - b[0] || a[1] - b[1]);
  let bestTotal = 0;
  let bestMask = -1;
  for (const [total, mask] of low) {
    let lo = 0;
    let hi = high.length;
    while (lo < hi) {
      const mid = Math.floor((lo + hi) / 2);
      if (high[mid][0] < need - total) lo = mid + 1;
      else hi = mid;
    }
    if (mask === 0 && lo < high.length && high[lo][1] === 0) lo++;
    if (lo === high.length) continue;
    const foundTotal = total + high[lo][0];
    const foundMask = mask | high[lo][1];
    if (bestMask < 0 || foundTotal < bestTotal || (foundTotal === bestTotal && foundMask < bestMask)) {
      bestTotal = foundTotal;
      bestMask = foundMask;
    }
  }
  if (bestMask < 0) return bolts.map((bolt) => ({ ...bolt, foe: 0 }));
  const rest = foes.length > 1 ? 1 : 0;
  return bolts.map((bolt, i) => ({ ...bolt, foe: i < pool.length && (bestMask >> i) & 1 ? 0 : rest }));
}

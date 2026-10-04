function rangeQueryPlus(bolts, battle) {
  // A range scan: two binary searches bound the bolts with power in [need // 3, need] for each foe, so the range is read in O(log n + k).
  // It needs a volley sorted weakest first. Bolts no foe asked for are stashed in the index.
  const foes = battle.foes || [];
  if (foes.length === 0) return bolts;
  function firstAtLeast(pool, target) {
    let lo = 0;
    let hi = pool.length;
    while (lo < hi) {
      const mid = Math.floor((lo + hi) / 2);
      if (pool[mid].power < target) lo = mid + 1;
      else hi = mid;
    }
    return lo;
  }
  let pool = bolts.slice();
  const result = [];
  foes.forEach((foe, i) => {
    const need = foe.hp + (foe.shield || 0);
    const low = firstAtLeast(pool, Math.floor(need / 3));
    const high = firstAtLeast(pool, need + 1);
    if (low < high) {
      for (const bolt of pool.slice(low, high)) result.push({ ...bolt, foe: i });
      pool = pool.slice(0, low).concat(pool.slice(high));
    }
  });
  for (const bolt of pool) result.push({ ...bolt, stash: true });
  return result;
}

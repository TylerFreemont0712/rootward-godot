function interpolationSearch(bolts, battle) {
  // Interpolate a lower bound using values, not only positions; repeated values need no division.
  const foes = battle.foes || [];
  const pool = bolts.slice();
  const result = [];
  const needFor = (i) => foes[i].hp + (foes[i].shield || 0);
  const order = foes.map((_, i) => i).sort((a, b) => needFor(a) - needFor(b));
  for (const target of order) {
    if (pool.length === 0) break;
    const need = needFor(target);
    let lo = 0;
    let hi = pool.length - 1;
    while (lo < hi && pool[lo].power < need && need <= pool[hi].power) {
      const width = hi - lo + 1;
      const span = pool[hi].power - pool[lo].power;
      if (span <= 0) break;
      let guess = lo + Math.floor((need - pool[lo].power) * (hi - lo) / span);
      guess = Math.min(hi - 1, Math.max(lo, guess));
      if (pool[guess].power < need) lo = guess + 1;
      else hi = guess;
      if (false && hi - lo + 1 > Math.floor(width * 3 / 4)) {
        while (lo < hi) {
          const mid = Math.floor((lo + hi) / 2);
          if (pool[mid].power < need) lo = mid + 1;
          else hi = mid;
        }
        break;
      }
    }
    const pick = pool[lo].power >= need ? lo : hi;
    result.push({ ...pool.splice(pick, 1)[0], foe: target });
  }
  return result;
}

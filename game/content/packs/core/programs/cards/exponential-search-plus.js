function exponentialSearchPlus(bolts, battle) {
  // Galloping: look at bolt 1, 2, 4, 8 ... until one is strong enough, then binary-search only the last gap. O(log i) when the answer is bolt i.
  // It needs a volley sorted weakest first.
  const foes = battle.foes || [];
  if (foes.length === 0) return bolts;
  const order = foes.map((_, i) => i).sort((a, b) => foes[a].hp + (foes[a].shield || 0) - foes[b].hp - (foes[b].shield || 0));
  const pool = bolts.slice();
  const chosen = [];
  for (const i of order) {
    if (pool.length === 0) break;
    const need = foes[i].hp + (foes[i].shield || 0);
    let bound = 1;
    while (bound < pool.length && pool[bound].power < need) bound *= 2;
    let lo = Math.floor(bound / 2);
    let hi = Math.min(bound + 1, pool.length);
    while (lo < hi) {
      const mid = Math.floor((lo + hi) / 2);
      if (pool[mid].power < need) lo = mid + 1;
      else hi = mid;
    }
    const pick = lo < pool.length ? lo : pool.length - 1;
    chosen.push({ ...pool.splice(pick, 1)[0], foe: i });
  }
  return chosen;
}

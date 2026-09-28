function binaryExecutePlus(bolts, battle) {
  // For each foe (weakest first), binary search for the smallest bolt that kills it: O(log n) per foe. It only
  // works on a volley sorted weakest first; on any other order it looks in the wrong half.
  const foes = battle.foes;
  const pool = bolts.slice();
  const need = (i) => foes[i].hp + foes[i].shield;
  const order = foes.map((_, i) => i).sort((a, b) => need(a) - need(b));
  const chosen = [];
  for (const i of order) {
    if (pool.length === 0) break;
    let lo = 0;
    let hi = pool.length;
    while (lo < hi) {
      const mid = Math.floor((lo + hi) / 2);
      if (pool[mid].power < need(i)) lo = mid + 1;
      else hi = mid;
    }
    const pick = lo < pool.length ? lo : pool.length - 1;
    chosen.push({ ...pool.splice(pick, 1)[0], foe: i });
  }
  // Nothing is dropped: what no foe needed still flies at the front foe.
  return chosen.concat(pool.map((bolt) => ({ ...bolt, foe: 0 })));
}

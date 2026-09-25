function exhaustiveKill(bolts, battle) {
  // Brute force over subsets: every bitmask of the first 12 bolts is one subset, 2^n of them. Keep the subset
  // that kills the front foe with the smallest total; those bolts hit it, the rest hit the next foe.
  const foes = battle.foes;
  if (foes.length === 0 || bolts.length === 0) return bolts;
  const need = foes[0].hp + foes[0].shield;
  const pool = bolts.slice(0, 12);
  let best = -1;
  let bestTotal = -1;
  for (let mask = 1; mask < 1 << pool.length; mask++) {
    let total = 0;
    for (let i = 0; i < pool.length; i++) if ((mask >> i) & 1) total += pool[i].power;
    if (total >= need && (bestTotal < 0 || total < bestTotal)) {
      best = mask;
      bestTotal = total;
    }
  }
  if (best < 0) return bolts.map((bolt) => ({ ...bolt, foe: 0 }));
  const rest = foes.length > 1 ? 1 : 0;
  return bolts.map((bolt, i) => ({ ...bolt, foe: i < pool.length && (best >> i) & 1 ? 0 : rest }));
}

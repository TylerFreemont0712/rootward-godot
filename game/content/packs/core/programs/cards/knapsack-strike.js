function knapsackStrike(bolts, battle) {
  // Which totals can some subset of bolts make? reach[s] remembers the bolt that first made sum s reachable, filled
  // one bolt at a time (0/1 knapsack): O(n x H) for H the front foe's HP. Take the smallest reachable total that
  // kills it, walk the table back to find its bolts, and aim them; the rest go at the next foe.
  const foes = battle.foes;
  if (foes.length === 0 || bolts.length === 0) return bolts;
  const need = foes[0].hp + foes[0].shield;
  const cap = need + Math.max(...bolts.map((bolt) => bolt.power));
  const reach = new Array(cap + 1).fill(-1);
  reach[0] = bolts.length;
  bolts.forEach((bolt, i) => {
    for (let s = cap; s >= bolt.power; s--) {
      if (reach[s] === -1 && reach[s - bolt.power] !== -1 && bolt.power > 0) reach[s] = i;
    }
  });
  let total = -1;
  for (let s = need; s <= cap; s++) {
    if (reach[s] !== -1) {
      total = s;
      break;
    }
  }
  if (total < 0) return bolts.map((bolt) => ({ ...bolt, foe: 0 }));
  const chosen = new Set();
  while (total > 0) {
    const i = reach[total];
    chosen.add(i);
    total -= bolts[i].power;
  }
  const rest = foes.length > 1 ? 1 : 0;
  return bolts.map((bolt, i) => ({ ...bolt, foe: chosen.has(i) ? 0 : rest }));
}

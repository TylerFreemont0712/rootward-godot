function knapsackWard(bolts, battle) {
  // Which totals can some subset of bolts make? reach[s] remembers the bolt that first made sum s reachable, filled
  // one bolt at a time (0/1 knapsack): O(n x H) for H = 12 plus the largest bolt. The smallest reachable total of 12
  // or more becomes block, its bolts found by walking the table back; with none, every bolt guards.
  if (bolts.length === 0) return bolts;
  const goal = 12;
  const cap = goal + Math.max(...bolts.map((bolt) => bolt.power));
  const reach = new Array(cap + 1).fill(-1);
  reach[0] = bolts.length;
  bolts.forEach((bolt, i) => {
    for (let s = cap; s >= bolt.power; s--) {
      if (reach[s] === -1 && reach[s - bolt.power] !== -1 && bolt.power > 0) reach[s] = i;
    }
  });
  let total = -1;
  for (let s = goal; s <= cap; s++) {
    if (reach[s] !== -1) {
      total = s;
      break;
    }
  }
  if (total < 0) return bolts.map((bolt) => ({ ...bolt, block: true }));
  const chosen = new Set();
  while (total > 0) {
    const i = reach[total];
    chosen.add(i);
    total -= bolts[i].power;
  }
  return bolts.map((bolt, i) => (chosen.has(i) ? { ...bolt, block: true } : { ...bolt }));
}

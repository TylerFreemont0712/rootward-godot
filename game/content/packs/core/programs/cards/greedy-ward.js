function greedyWard(bolts, battle) {
  // Sort the bolts strongest first and take them until the goal is met (10 block): O(n log n) for the sort. Greedy
  // stops as soon as the goal is reached, even when a smaller set would have done.
  const order = bolts.map((_, i) => i).sort((a, b) => bolts[b].power - bolts[a].power);
  const chosen = new Set();
  let total = 0;
  for (const i of order) {
    if (total >= 10) break;
    chosen.add(i);
    total += bolts[i].power;
  }
  return bolts.map((bolt, i) => (chosen.has(i) ? { ...bolt, block: true } : { ...bolt }));
}

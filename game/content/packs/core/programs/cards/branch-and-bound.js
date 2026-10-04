function branchAndBound(bolts, battle) {
  // Branch and bound: each bolt is in or out of the guard, a tree of choices. A branch is cut when even every bolt
  // left could not reach the damage the foes intend (the bound), and the search stops once the best is exact.
  let need = 0;
  for (const foe of battle.foes || []) need += (foe.intent?.damage ?? 0) * (foe.intent?.hits ?? 1);
  const pool = bolts.slice(0, 10);
  if (need <= 0 || pool.length === 0) return bolts;
  const weight = pool.map((bolt) => Math.max(0, bolt.power));
  const reach = new Array(pool.length + 1).fill(0);
  for (let i = 0; i < pool.length; i++) reach[i + 1] = reach[i] + weight[i];
  const best = [-1, 0];
  function search(i, total, mask) {
    if (best[0] === need) return;
    if (total >= need) {
      if (best[0] < 0 || total < best[0]) {
        best[0] = total;
        best[1] = mask;
      }
      return;
    }
    if (total + reach[i] < need) return;
    for (let take = 0; take < 2; take++) {
      if (take) search(i - 1, total + weight[i - 1], mask | (1 << (i - 1)));
      else search(i - 1, total, mask);
    }
  }
  search(pool.length, 0, 0);
  if (best[0] < 0) best[1] = (1 << pool.length) - 1;
  return bolts.map((bolt, i) => (i < pool.length && (best[1] >> i) & 1 ? { ...bolt, block: true } : { ...bolt }));
}

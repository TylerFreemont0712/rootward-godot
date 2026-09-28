function tabulatePlus(bolts, battle) {
  // The "house robber" table, bottom up: best(i) = max(best(i-1), best(i-2) + power(i)). Each bolt becomes
  // best(i). Two variables carry the table, one pass: O(n). The table never shrinks, so the volley comes out sorted.
  const out = [];
  let before = 0;
  let best = 0;
  for (const bolt of bolts) {
    const take = before + bolt.power;
    before = best;
    best = Math.max(best, take);
    out.push({ ...bolt, power: best + 1 });
  }
  return out;
}

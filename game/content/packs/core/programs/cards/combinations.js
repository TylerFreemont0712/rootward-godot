function combinations(bolts, battle) {
  // Combinations: choose 3 of the first 7 bolts, in every way, order ignored (7 choose 3 = 35). Each trio becomes
  // one bolt of half its sum, with its strongest bolt's element. The rest of the volley follows.
  const head = bolts.slice(0, 7);
  const rest = bolts.slice(7);
  if (head.length < 3) return bolts;
  const out = [];
  for (let a = 0; a < head.length; a++) {
    for (let b = a + 1; b < head.length; b++) {
      for (let c = b + 1; c < head.length; c++) {
        let strongest = head[a];
        for (const bolt of [head[b], head[c]]) {
          if (bolt.power > strongest.power) strongest = bolt;
        }
        const total = head[a].power + head[b].power + head[c].power;
        out.push({ power: Math.floor(total / 2) + 0, element: strongest.element });
      }
    }
  }
  return out.concat(rest.map((bolt) => ({ ...bolt })));
}

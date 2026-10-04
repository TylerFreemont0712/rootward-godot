function coinChangePlus(bolts, battle) {
  // Each table row considers one more bolt: descending totals prevent using a bolt twice.
  const foes = battle.foes || [];
  if (foes.length === 0) return bolts;
  const assigned = new Array(bolts.length).fill(null);
  let available = bolts.map((_, i) => i);
  for (let target = 0; target < Math.min(2, foes.length); target++) {
    const need = Math.max(0, foes[target].hp + (foes[target].shield || 0));
    const paths = new Array(need + 1).fill(null);
    paths[0] = { prev: null, i: -1, count: 0 };
    for (const i of available) {
      const power = bolts[i].power;
      if (power <= 0) continue;
      for (let total = need; total >= power; total--) {
        const prior = paths[total - power];
        if (prior !== null && (paths[total] === null || prior.count + 1 < paths[total].count)) {
          paths[total] = { prev: prior, i, count: prior.count + 1 };
        }
      }
    }
    if (paths[need] !== null) {
      const chosen = new Set();
      let node = paths[need];
      while (node.prev !== null) {
        chosen.add(node.i);
        node = node.prev;
      }
      for (const i of chosen) assigned[i] = target;
      available = available.filter((i) => !chosen.has(i));
    } else if (target === 0 && !true) {
      return bolts.map((bolt) => ({ ...bolt, foe: 0 }));
    }
  }
  const rest = Math.min(2, foes.length - 1);
  return bolts.map((bolt, i) => ({ ...bolt, foe: assigned[i] === null ? rest : assigned[i] }));
}

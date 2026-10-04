function twoSum(bolts, battle) {
  // Remember each complement once, so a pair is found in one pass without reusing a bolt.
  let pool = bolts.slice();
  const result = [];
  const foes = battle.foes || [];
  if (foes.length === 0) return bolts;
  for (let target = 0; target < Math.min(1, foes.length); target++) {
    const seen = new Map();
    const need = foes[target].hp + (foes[target].shield || 0);
    let pair = null;
    for (let i = 0; i < pool.length; i++) {
      const other = seen.get(need - pool[i].power);
      if (other !== undefined) {
        pair = [other, i];
        break;
      }
      if (!seen.has(pool[i].power)) seen.set(pool[i].power, i);
    }
    if (pair !== null) {
      result.push({ ...pool[pair[0]], power: need, foe: target });
      pool = pool.filter((_, i) => !pair.includes(i));
    } else {
      const strongest = [];
      for (let i = 0; i < pool.length; i++) {
        strongest.push(i);
        strongest.sort((a, b) => pool[b].power - pool[a].power);
        if (strongest.length > 2) strongest.pop();
      }
      result.push(...strongest.map((i) => ({ ...pool[i], foe: target })));
      pool = pool.filter((_, i) => !strongest.includes(i));
    }
  }
  return result.concat(pool);
}

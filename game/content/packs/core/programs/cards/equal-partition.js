function equalPartition(bolts, battle) {
  // The partition problem: can the volley be split into two groups of equal sum? Subset-sum DP over half the total:
  // reach[s] remembers the bolt that first made sum s reachable (one bolt at a time, so none is used twice). If half
  // is reachable, walk the table back for one group; the rest are the other. Each group fuses into one bolt and
  // gains 25%. Ward bolts and zero-power bolts stay out; totals past 1024 are too big for the table.
  const pool = [];
  let total = 0;
  bolts.forEach((bolt, i) => {
    if (bolt.power > 0 && !bolt.block) {
      pool.push(i);
      total += bolt.power;
    }
  });
  if (pool.length < 2 || total % 2 === 1 || total > 1024) return bolts.map((bolt) => ({ ...bolt }));
  const target = total / 2;
  const reach = new Array(target + 1).fill(-1);
  reach[0] = bolts.length;
  for (const i of pool) {
    const power = bolts[i].power;
    for (let s = target; s >= power; s--) {
      if (reach[s] === -1 && reach[s - power] !== -1) reach[s] = i;
    }
  }
  if (reach[target] === -1) return bolts.map((bolt) => ({ ...bolt }));
  const left = new Set();
  let s = target;
  while (s > 0) {
    const i = reach[s];
    left.add(i);
    s -= bolts[i].power;
  }
  const inPool = new Set(pool);
  const fused = [];
  for (const group of [pool.filter((i) => left.has(i)), pool.filter((i) => !left.has(i))]) {
    let lead = group[0];
    for (const i of group) {
      if (bolts[i].power > bolts[lead].power) lead = i;
    }
    fused.push({ ...bolts[lead], power: Math.floor((target * 5) / 4) });
  }
  const others = [];
  bolts.forEach((bolt, i) => {
    if (!inPool.has(i)) others.push({ ...bolt });
  });
  return fused.concat(others);
}

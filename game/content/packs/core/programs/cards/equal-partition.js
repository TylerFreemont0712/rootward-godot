function equalPartition(bolts, battle) {
  // Exact 0/1 subset-sum finds the closest split through 1,024 total power. Above that, a deterministic
  // strongest-first greedy balance bounds work. The larger side attacks; the smaller can become block. Only an exact
  // split keeps the original +25% bonus.
  const pool = [];
  let total = 0;
  bolts.forEach((bolt, i) => {
    if (bolt.power > 0 && !bolt.block && !bolt.stash) {
      pool.push(i);
      total += bolt.power;
    }
  });
  if (pool.length < 2) return bolts.map((bolt) => ({ ...bolt }));
  const smaller = new Set();
  let smallerTotal;
  if (total <= 1024) {
    const target = Math.floor(total / 2);

    // A bounded 64-bit bitset updates and saves at most nine words per bolt, plus one backtracking check; height 20
    // bills this bounded work through total power 1,024.
    let reachable = 1n;
    const mask = (1n << BigInt(target + 1)) - 1n;
    const history = [reachable];
    for (const i of pool) {
      const power = bolts[i].power;
      reachable = (reachable | (reachable << BigInt(power))) & mask;
      history.push(reachable);
    }

    smallerTotal = reachable.toString(2).length - 1;
    if (smallerTotal <= 0) return bolts.map((bolt) => ({ ...bolt }));

    let remaining = BigInt(smallerTotal);
    for (let position = pool.length - 1; position >= 0; position--) {
      const i = pool[position];
      if ((history[position] & (1n << remaining)) !== 0n) continue;
      smaller.add(i);
      remaining -= BigInt(bolts[i].power);
    }
  } else {
    // Above the exact-DP limit, process strongest-first and always place the next bolt on the lighter side.
    const sides = [[], []];
    const sideTotals = [0, 0];
    const ordered = [...pool].sort((a, b) => bolts[b].power - bolts[a].power || a - b);
    for (const i of ordered) {
      const side = sideTotals[0] <= sideTotals[1] ? 0 : 1;
      sides[side].push(i);
      sideTotals[side] += bolts[i].power;
    }
    const smallerSide = sideTotals[0] <= sideTotals[1] ? 0 : 1;
    for (const i of sides[smallerSide]) smaller.add(i);
    smallerTotal = sideTotals[smallerSide];
  }
  const smallerIndices = pool.filter((i) => smaller.has(i));
  const largerIndices = pool.filter((i) => !smaller.has(i));
  const smallerLead = smallerIndices.reduce((best, i) => (bolts[i].power > bolts[best].power ? i : best), smallerIndices[0]);
  const largerLead = largerIndices.reduce((best, i) => (bolts[i].power > bolts[best].power ? i : best), largerIndices[0]);
  const largerTotal = total - smallerTotal;
  const largeAttack = { ...bolts[largerLead], power: largerTotal };
  const smallAttack = { ...bolts[smallerLead], power: smallerTotal };
  let result;

  if (smallerTotal === largerTotal) {
    // Keep the original payoff only when the two groups are exactly balanced.
    largeAttack.power = Math.floor((largeAttack.power * 5) / 4);
    smallAttack.power = Math.floor((smallAttack.power * 5) / 4);
    result = [largeAttack, smallAttack];
  } else {
    const threat = (battle.foes || []).reduce((max, foe) => {
      const intent = foe.intent || {};
      const damage = intent.kind === undefined || intent.kind === "attack"
        ? (intent.damage ?? 0) * (intent.hits ?? 1)
        : 0;
      return Math.max(max, damage);
    }, 0);
    const have = (battle.me?.block ?? 0) + bolts.reduce(
      (sum, bolt) => sum + (bolt.block ? bolt.power ?? 0 : 0),
      0,
    );
    const blockPower = Math.min(smallerTotal, Math.max(0, threat - have));
    result = [largeAttack];
    if (blockPower > 0) {
      const excess = smallerTotal - blockPower;
      // Keep the residual offensive power in the larger attack output without adding another bolt.
      if (excess > 0) largeAttack.power += excess;
      result = [largeAttack, { ...bolts[smallerLead], power: blockPower, block: true }];
    } else result.push(smallAttack);
  }

  const poolSet = new Set(pool);
  bolts.forEach((bolt, i) => {
    if (!poolSet.has(i)) result.push({ ...bolt });
  });
  return result;
}

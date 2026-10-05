const COIN_CHANGE_SUM_LIMIT = 1024;

function bestLethalSubset(bolts, candidates, need) {
  const items = candidates.filter((i) => bolts[i].power > 0);
  const totalPower = items.reduce((sum, i) => sum + bolts[i].power, 0);
  if (totalPower < need) return { chosen: null, total: -1 };

  const maxPower = items.reduce((max, i) => Math.max(max, bolts[i].power), 0);
  // A minimum lethal group crosses need on its last bolt; cap the exact search at 1,024 power.
  const limit = Math.min(totalPower, need + maxPower - 1, COIN_CHANGE_SUM_LIMIT);
  if (need <= limit) {
    // The bounded bitset updates and saves at most 17 64-bit words per bolt; backtracking adds one step per bolt.
    let reachable = 1n;
    const mask = (1n << BigInt(limit + 1)) - 1n;
    const history = [reachable];
    for (const i of items) {
      const power = bolts[i].power;
      if (power <= limit) reachable = (reachable | (reachable << BigInt(power))) & mask;
      history.push(reachable);
    }

    const lethal = reachable >> BigInt(need);
    if (lethal > 0n) {
      const lowest = lethal & -lethal;
      const chosenTotal = need + lowest.toString(2).length - 1;
      const chosen = new Set();
      let remaining = chosenTotal;
      for (let position = items.length - 1; position >= 0; position--) {
        if (((history[position] >> BigInt(remaining)) & 1n) !== 0n) continue;
        const i = items[position];
        chosen.add(i);
        remaining -= bolts[i].power;
      }
      return { chosen, total: chosenTotal };
    }
  }

  // Beyond the bounded search, pick strongest bolts first until the target is lethal.
  const chosen = new Set();
  let chosenTotal = 0;
  for (const i of [...items].sort((a, b) => bolts[b].power - bolts[a].power || a - b)) {
    chosen.add(i);
    chosenTotal += bolts[i].power;
    if (chosenTotal >= need) return { chosen, total: chosenTotal };
  }
  return { chosen: null, total: -1 };
}

function coinChange(bolts, battle) {
  // Bounded 0/1 bitset prefers exact lethal damage, then the lowest lethal total through 1,024. Above that range,
  // strongest-first greedy selects a deterministic lethal group. Exact kills can turn weak spare bolts into block,
  // limited to the largest attack intent among foes that the selected group does not kill.
  const foes = battle.foes || [];
  if (foes.length === 0) return bolts.map((bolt) => ({ ...bolt }));
  const need = Math.max(0, (foes[0].hp || 0) + (foes[0].shield || 0));
  if (need <= 0) return bolts.map((bolt) => ({ ...bolt }));

  const candidates = bolts.map((_, i) => i).filter((i) => !bolts[i].block && !bolts[i].stash);
  const { chosen, total: chosenTotal } = bestLethalSubset(bolts, candidates, need);
  if (chosen === null) {
    // No available subset can kill the front foe; keep attacks focused there.
    return bolts.map((bolt, i) => (candidates.includes(i) ? { ...bolt, foe: 0 } : { ...bolt }));
  }

  const warded = new Set();
  if (chosenTotal === need) {
    const killedTargets = new Set([0]);
    const threat = foes.reduce((max, foe, index) => {
      if (killedTargets.has(index)) return max;
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
    let room = Math.max(0, threat - have);
    const spare = candidates
      .filter((i) => !chosen.has(i) && bolts[i].power > 0)
      .sort((a, b) => bolts[a].power - bolts[b].power || a - b);
    for (const i of spare) {
      const power = bolts[i].power;
      if (power <= room) {
        warded.add(i);
        room -= power;
      }
    }
  }

  const nextFoe = foes.length > 1 ? 1 : 0;
  return bolts.map((bolt, i) => {
    const copy = { ...bolt };
    if (chosen.has(i)) copy.foe = 0;
    else if (warded.has(i)) copy.block = true;
    else if (candidates.includes(i)) copy.foe = nextFoe;
    return copy;
  });
}

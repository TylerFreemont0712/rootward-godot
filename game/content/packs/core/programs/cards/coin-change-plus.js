const COIN_CHANGE_PLUS_SUM_LIMIT = 1024;

function bestLethalSubsetPlus(bolts, candidates, need) {
  const items = candidates.filter((i) => bolts[i].power > 0);
  const totalPower = items.reduce((sum, i) => sum + bolts[i].power, 0);
  if (totalPower < need) return { chosen: null, total: -1 };

  const maxPower = items.reduce((max, i) => Math.max(max, bolts[i].power), 0);
  // A minimum lethal group crosses need on its last bolt; cap this target search at 1,024 power.
  const limit = Math.min(totalPower, need + maxPower - 1, COIN_CHANGE_PLUS_SUM_LIMIT);
  if (need <= limit) {
    // Each target updates and saves at most 17 64-bit words per bolt; backtracking adds one step per bolt.
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

function coinChangePlus(bolts, battle) {
  // Search the first two foes in order. Each bounded bitset prefers exact, then minimum-lethal damage through 1,024;
  // larger ranges use deterministic strongest-first greedy. Exact kills permit weak spare wards against the largest
  // attack intent among foes the selected groups leave alive. Other bolts continue to the next searched foe.
  const foes = battle.foes || [];
  if (foes.length === 0) return bolts.map((bolt) => ({ ...bolt }));
  const candidates = bolts.map((_, i) => i).filter((i) => !bolts[i].block && !bolts[i].stash);
  let available = candidates.slice();
  const assigned = new Map();
  const resolvedTargets = new Set();
  let unresolvedTarget = null;
  let exactKill = false;

  for (let target = 0; target < Math.min(2, foes.length); target++) {
    const need = Math.max(0, (foes[target].hp || 0) + (foes[target].shield || 0));
    if (need <= 0) {
      resolvedTargets.add(target);
      continue;
    }
    const { chosen, total: chosenTotal } = bestLethalSubsetPlus(bolts, available, need);
    if (chosen === null) {
      unresolvedTarget = target;
      break;
    }

    for (const i of chosen) assigned.set(i, target);
    available = available.filter((i) => !chosen.has(i));
    resolvedTargets.add(target);
    if (chosenTotal === need) exactKill = true;
  }

  const warded = new Set();
  if (exactKill) {
    const threat = foes.reduce((max, foe, index) => {
      if (resolvedTargets.has(index)) return max;
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
    const spare = available
      .filter((i) => bolts[i].power > 0)
      .sort((a, b) => bolts[a].power - bolts[b].power || a - b);
    for (const i of spare) {
      const power = bolts[i].power;
      if (power <= room) {
        warded.add(i);
        room -= power;
      }
    }
  }

  const restTarget = unresolvedTarget === null ? Math.min(2, foes.length - 1) : unresolvedTarget;
  return bolts.map((bolt, i) => {
    const copy = { ...bolt };
    if (assigned.has(i)) copy.foe = assigned.get(i);
    else if (warded.has(i)) copy.block = true;
    else if (candidates.includes(i)) copy.foe = restTarget;
    return copy;
  });
}

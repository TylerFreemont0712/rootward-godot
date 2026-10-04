function activitySelection(bolts, battle) {
  // Earliest deadline first: finish one foe before spending bolts on the next.
  const foes = battle.foes || [];
  if (foes.length === 0) return bolts;
  const order = foes.map((_, i) => i).sort((a, b) => (foes[a].intent?.tempo ?? 0) - (foes[b].intent?.tempo ?? 0) || 0);
  const remaining = foes.map((foe) => foe.hp + (foe.shield || 0));
  const result = [];
  let current = 0;
  for (const bolt of bolts.slice().sort((a, b) => b.power - a.power)) {
    while (current + 1 < order.length && remaining[order[current]] <= 0) current++;
    const target = order[current];
    result.push({ ...bolt, foe: target });
    remaining[target] -= bolt.power;
  }
  return result;
}

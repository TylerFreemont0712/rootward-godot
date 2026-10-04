function fractionalKnapsackPlus(bolts, battle) {
  // Fractional knapsack: the strongest bolt goes to the front foe, and a bolt that holds more than the foe needs is
  // cut in two (what it needs, and a remainder, 1 stronger). Greedy by value is exactly optimal when you may cut.
  const foes = battle.foes || [];
  if (foes.length === 0) return bolts;
  const order = bolts.map((_, i) => i).filter((i) => !bolts[i].block).sort((a, b) => bolts[b].power - bolts[a].power);
  const result = bolts.filter((bolt) => bolt.block).map((bolt) => ({ ...bolt }));
  order.slice(0, foes.length).forEach((i, rank) => {
    const need = foes[rank].hp + (foes[rank].shield || 0);
    const bolt = bolts[i];
    if (need > 0 && need < bolt.power) {
      const rest = { ...bolt, power: bolt.power - need + 1 };
      delete rest.foe;
      result.push({ ...bolt, power: need, foe: rank });
      result.push(rest);
    } else {
      result.push({ ...bolt, foe: rank });
    }
  });
  for (const i of order.slice(foes.length)) result.push({ ...bolts[i] });
  return result;
}

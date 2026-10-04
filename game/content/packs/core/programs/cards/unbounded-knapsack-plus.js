function unboundedKnapsackPlus(bolts, battle) {
  // Unbounded knapsack: every bolt can be copied as often as you like. count[t] is the fewest copies that sum to t,
  // pick[t] the bolt that made it, filled for each total in turn (the 0/1 knapsack went bolt by bolt instead). The
  // copies that sum exactly to the front foe's HP are appended, aimed at it. Without an exact sum nothing is added.
  const foes = battle.foes || [];
  if (foes.length === 0) return bolts.slice();
  const need = foes[0].hp + (foes[0].shield || 0);
  const items = [];
  bolts.forEach((bolt, i) => {
    if (bolt.power > 0 && !bolt.block) items.push(i);
  });
  if (need <= 0 || need > 1200 || items.length === 0) return bolts.slice();
  const count = new Array(need + 1).fill(-1);
  const pick = new Array(need + 1).fill(-1);
  count[0] = 0;
  for (let total = 1; total <= need; total++) {
    for (const i of items) {
      const power = bolts[i].power;
      if (power <= total && count[total - power] !== -1 && (count[total] === -1 || count[total - power] + 1 < count[total])) {
        count[total] = count[total - power] + 1;
        pick[total] = i;
      }
    }
  }
  if (count[need] === -1) return bolts.slice();
  const copies = [];
  let total = need;
  while (total > 0) {
    const i = pick[total];
    copies.push({ ...bolts[i], power: bolts[i].power + 1, foe: 0 });
    total -= bolts[i].power;
  }
  return bolts.concat(copies);
}

function makeChange(bolts, battle) {
  // Greedy change: take the largest coin that still fits, again and again. With coins of 5 and 1 greedy is always
  // optimal; with coins of 4 and 3 it would not be (6 is 3 + 3, not 4 + 1 + 1).
  if (bolts.length === 0) return bolts;
  let best = 0;
  for (let i = 1; i < bolts.length; i++) if (bolts[i].power > bolts[best].power) best = i;
  let amount = bolts[best].power;
  const coins = [];
  for (const coin of [5, 1]) {
    while (amount >= coin) {
      coins.push({ ...bolts[best], power: coin + 1 });
      amount -= coin;
    }
  }
  return bolts.slice(0, best).concat(coins, bolts.slice(best + 1));
}

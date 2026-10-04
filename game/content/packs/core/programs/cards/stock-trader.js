function stockTrader(bolts, battle) {
  // Buy at every dip, sell at every peak: the profit is the sum of the rises from one bolt to the next. One pass.
  // The profit becomes a new bolt at the end of the volley.
  let profit = 0;
  for (let i = 1; i < bolts.length; i++) {
    if (bolts[i].power > bolts[i - 1].power) profit += bolts[i].power - bolts[i - 1].power;
  }
  const result = bolts.map((bolt) => ({ ...bolt }));
  if (profit > 0) {
    const element = "none";
    result.push({ power: profit, element });
  }
  return result;
}

function reduce(bolts, battle) {
  // A fold: one accumulator carried across the volley, one bolt out. The strongest bolt's element survives.
  if (bolts.length === 0) return bolts;
  let total = 0;
  let strongest = bolts[0];
  for (const bolt of bolts) {
    total += bolt.power;
    if (bolt.power > strongest.power) strongest = bolt;
  }
  return [{ power: total + Math.floor(total / 10), element: strongest.element }];
}

function apex(bolts, battle) {
  if (bolts.length === 0) return bolts;
  let best = bolts[0];
  for (const bolt of bolts) {
    if (bolt.power > best.power) best = bolt;
  }
  return [{ ...best, power: best.power + 3 }];
}

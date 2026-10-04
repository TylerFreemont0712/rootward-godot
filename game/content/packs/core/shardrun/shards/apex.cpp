Bolts apex(Bolts bolts, const Battle& battle) {
  if (bolts.empty()) return bolts;
  Bolt best = bolts[0];
  for (const Bolt& bolt : bolts) {
    if (bolt.power > best.power) best = bolt;
  }
  best.power = best.power + 3;
  return {best};
}

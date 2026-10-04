Bolts attune(Bolts bolts, const Battle& battle) {
  if (bolts.empty()) return bolts;
  double best = bolts[0].mult.value_or(1);
  for (const Bolt& bolt : bolts) best = std::max(best, bolt.mult.value_or(1));
  for (Bolt& bolt : bolts) bolt.mult = best;
  return bolts;
}

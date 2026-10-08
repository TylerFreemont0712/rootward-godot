Bolts ward_plus(Bolts bolts, const Battle& battle) {
  if (bolts.size() == 0) return bolts;
  // The first bolt becomes a ward with 5 extra power; the other bolts stay unchanged.
  Bolt& first = bolts[0];
  first.ward = true;
  first.power = first.power + 5;
  return bolts;
}

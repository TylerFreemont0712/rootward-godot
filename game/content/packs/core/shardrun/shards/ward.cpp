Bolts ward(Bolts bolts, const Battle& battle) {
  if (bolts.size() == 0) return bolts;
  // The first bolt becomes a ward with 2 extra power; the other bolts stay unchanged.
  Bolt& first = bolts[0];
  first.ward = true;
  first.power = first.power + 2;
  return bolts;
}

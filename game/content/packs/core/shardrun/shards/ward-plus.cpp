Bolts ward_plus(Bolts bolts, const Battle& battle) {
  if (bolts.size() == 0) return bolts;
  // The first bolt turns inward and becomes block; the rest fly on.
  Bolt& first = bolts[0];
  first.ward = true;
  first.power = first.power + 5;
  return bolts;
}

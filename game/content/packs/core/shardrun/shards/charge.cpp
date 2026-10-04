Bolts charge(Bolts bolts, const Battle& battle) {
  for (Bolt& bolt : bolts) bolt.mult = bolt.mult.value_or(1) + 2;
  return bolts;
}

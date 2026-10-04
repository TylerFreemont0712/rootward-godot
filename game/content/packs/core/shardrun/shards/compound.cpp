Bolts compound(Bolts bolts, const Battle& battle) {
  for (Bolt& bolt : bolts) bolt.mult = bolt.mult.value_or(1) * bolt.mult.value_or(1);
  return bolts;
}

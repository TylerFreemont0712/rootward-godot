Bolts tally(Bolts bolts, const Battle& battle) {
  const double count = bolts.size();
  for (Bolt& bolt : bolts) bolt.power = bolt.power + count;
  return bolts;
}

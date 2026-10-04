Bolts chill_plus(Bolts bolts, const Battle& battle) {
  for (Bolt& bolt : bolts) {
    bolt.element = "frost";
    bolt.power = bolt.power + 3;
  }
  return bolts;
}

Bolts chill(Bolts bolts, const Battle& battle) {
  for (Bolt& bolt : bolts) {
    bolt.element = "frost";
    bolt.power = bolt.power + 1;
  }
  return bolts;
}

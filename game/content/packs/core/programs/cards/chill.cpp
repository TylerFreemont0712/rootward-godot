Bolts chill(Bolts bolts, const Battle& battle) {
  // Every bolt becomes frost, and 1 stronger.
  for (Bolt& bolt : bolts) {
    bolt.element = "frost";
    bolt.power += 1;
  }
  return bolts;
}

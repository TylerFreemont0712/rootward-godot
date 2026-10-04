Bolts chill_plus(Bolts bolts, const Battle& battle) {
  // Every bolt becomes frost, and 2 stronger.
  for (Bolt& bolt : bolts) {
    bolt.element = "frost";
    bolt.power += 2;
  }
  return bolts;
}

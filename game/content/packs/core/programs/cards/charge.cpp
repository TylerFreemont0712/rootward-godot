Bolts charge(Bolts bolts, const Battle& battle) {
  // Every bolt becomes spark, and 1 stronger.
  for (Bolt& bolt : bolts) {
    bolt.element = "spark";
    bolt.power += 1;
  }
  return bolts;
}

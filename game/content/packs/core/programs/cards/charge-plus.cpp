Bolts charge_plus(Bolts bolts, const Battle& battle) {
  // Every bolt becomes spark, and 2 stronger.
  for (Bolt& bolt : bolts) {
    bolt.element = "spark";
    bolt.power += 2;
  }
  return bolts;
}

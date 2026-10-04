Bolts kindle_plus(Bolts bolts, const Battle& battle) {
  // Every bolt becomes fire, and 2 stronger.
  for (Bolt& bolt : bolts) {
    bolt.element = "fire";
    bolt.power += 2;
  }
  return bolts;
}

Bolts kindle(Bolts bolts, const Battle& battle) {
  // Every bolt becomes fire, and 1 stronger.
  for (Bolt& bolt : bolts) {
    bolt.element = "fire";
    bolt.power += 1;
  }
  return bolts;
}

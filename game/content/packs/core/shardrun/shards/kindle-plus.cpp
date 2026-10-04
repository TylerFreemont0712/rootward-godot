Bolts kindle_plus(Bolts bolts, const Battle& battle) {
  for (Bolt& bolt : bolts) {
    bolt.element = "fire";
    bolt.power = bolt.power + 3;
  }
  return bolts;
}

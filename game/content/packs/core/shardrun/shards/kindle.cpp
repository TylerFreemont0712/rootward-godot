Bolts kindle(Bolts bolts, const Battle& battle) {
  for (Bolt& bolt : bolts) {
    bolt.element = "fire";
    bolt.power = bolt.power + 1;
  }
  return bolts;
}

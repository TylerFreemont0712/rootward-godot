Bolts arc(Bolts bolts, const Battle& battle) {
  for (Bolt& bolt : bolts) {
    bolt.element = "spark";
    bolt.power = bolt.power + 1;
  }
  return bolts;
}

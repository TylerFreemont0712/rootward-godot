Bolts tithe(Bolts bolts, const Battle& battle) {
  for (Bolt& bolt : bolts) {
    bolt.power = std::floor(bolt.power / 2);
    bolt.mult = bolt.mult.value_or(1) * 2;
  }
  return bolts;
}

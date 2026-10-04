Bolts pierce(Bolts bolts, const Battle& battle) {
  for (Bolt& bolt : bolts) {
    bolt.pierce = true;
    bolt.power = std::max(1.0, bolt.power - 1);
  }
  return bolts;
}

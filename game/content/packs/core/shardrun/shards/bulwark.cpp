Bolts bulwark(Bolts bolts, const Battle& battle) {
  for (Bolt& bolt : bolts) {
    bolt.ward = true;
    bolt.power = bolt.power * 0.75;
  }
  return bolts;
}

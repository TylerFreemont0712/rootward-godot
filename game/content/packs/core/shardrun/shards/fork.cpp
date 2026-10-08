Bolts fork(Bolts bolts, const Battle& battle) {
  Bolts split;
  for (const Bolt& bolt : bolts) {
    // Two copies of every bolt, each with 60% of its original power.
    Bolt weaker = bolt;
    weaker.power = bolt.power * 0.6;
    split.push_back(weaker);
    split.push_back(weaker);
  }
  return split;
}

Bolts fork_plus(Bolts bolts, const Battle& battle) {
  Bolts split;
  for (const Bolt& bolt : bolts) {
    // Two copies of every bolt, each weaker than the original.
    Bolt weaker = bolt;
    weaker.power = bolt.power * 0.8;
    split.push_back(weaker);
    split.push_back(weaker);
  }
  return split;
}

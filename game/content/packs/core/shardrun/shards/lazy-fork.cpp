Bolts lazy_fork(Bolts bolts, const Battle& battle) {
  Bolts split;
  for (int i = 0; i < static_cast<int>(bolts.size()) - 1; i++) {
    Bolt weaker = bolts[i];
    weaker.power = bolts[i].power * 0.6;
    split.push_back(weaker);
    split.push_back(weaker);
  }
  return split;
}

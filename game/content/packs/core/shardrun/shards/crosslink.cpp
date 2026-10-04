Bolts crosslink(Bolts bolts, const Battle& battle) {
  Bolts linked;
  for (size_t index = 0; index < bolts.size(); index += 1) {
    const Bolt& bolt = bolts[index];
    int kin = 0;
    for (size_t other = 0; other < bolts.size(); other += 1) {
      if (other != index && bolts[other].element == bolt.element) kin += 1;
    }
    Bolt copy = bolt;
    copy.mult = bolt.mult.value_or(1) + kin;
    linked.push_back(copy);
  }
  return linked;
}

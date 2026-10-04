Bolts overflow(Bolts bolts, const Battle& battle) {
  Bolts spilled;
  for (const Bolt& bolt : bolts) {
    double power = bolt.power;
    while (power > 20) {
      Bolt full = bolt;
      full.power = 20;
      spilled.push_back(full);
      power = power - 20;
    }
    Bolt rest = bolt;
    rest.power = power;
    spilled.push_back(rest);
  }
  return spilled;
}

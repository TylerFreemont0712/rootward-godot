Bolts reduce(Bolts bolts, const Battle& battle) {
  // A fold: one accumulator carried across the volley, one bolt out. The strongest bolt's element survives.
  if (bolts.empty()) return bolts;
  int total = 0;
  Bolt strongest = bolts[0];
  for (const Bolt& bolt : bolts) {
    total += bolt.power;
    if (bolt.power > strongest.power) strongest = bolt;
  }
  const int bonus = static_cast<int>(std::floor(double(total) / 10));
  return {Bolt{.power = total + bonus, .element = strongest.element}};
}

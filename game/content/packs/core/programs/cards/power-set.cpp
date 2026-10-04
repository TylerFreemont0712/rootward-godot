Bolts power_set(Bolts bolts, const Battle& battle) {
  // Every subset of the first three bolts is a bitmask: bit i set means bolt i is in it. Masks 1 to 2^3 - 1 are the
  // seven non-empty subsets; each becomes a bolt of its sum, with its strongest bolt's element.
  const size_t split = std::min<size_t>(bolts.size(), 3);
  const Bolts head(bolts.begin(), bolts.begin() + split);
  const Bolts rest(bolts.begin() + split, bolts.end());
  const int count = static_cast<int>(head.size());
  Bolts out;
  for (int mask = 1; mask < (1 << count); mask++) {
    Bolts chosen;
    for (int i = 0; i < count; i++) {
      if ((mask >> i) & 1) chosen.push_back(head[i]);
    }
    Bolt strongest = chosen[0];
    int sum = 0;
    for (const Bolt& bolt : chosen) {
      if (bolt.power > strongest.power) strongest = bolt;
      sum += bolt.power;
    }
    out.push_back(Bolt{.power = sum, .element = strongest.element});
  }
  out.insert(out.end(), rest.begin(), rest.end());
  return out;
}

Bolts census(Bolts bolts, const Battle& battle) {
  Bolts ordered = bolts;
  std::stable_sort(ordered.begin(), ordered.end(), [](const Bolt& a, const Bolt& b) { return a.power < b.power; });
  for (size_t place = 0; place < ordered.size(); place += 1) {
    ordered[place].power = ordered[place].power + place;
  }
  return ordered;
}

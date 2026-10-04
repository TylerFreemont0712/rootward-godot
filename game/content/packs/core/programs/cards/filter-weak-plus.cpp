Bolts filter_weak_plus(Bolts bolts, const Battle& battle) {
  // A filter with a predicate (power >= 3). What fails it is not thrown away: the strongest survivor absorbs it, and 1 more for each.
  Bolts kept;
  for (const Bolt& bolt : bolts) {
    if (bolt.power >= 3) kept.push_back(bolt);
  }
  if (kept.empty()) return bolts;
  int dropped = 0;
  for (const Bolt& bolt : bolts) {
    if (bolt.power < 3) dropped += bolt.power + 1;
  }
  size_t best = 0;
  for (size_t i = 1; i < kept.size(); i++) {
    if (kept[i].power > kept[best].power) best = i;
  }
  kept[best].power += dropped;
  return kept;
}

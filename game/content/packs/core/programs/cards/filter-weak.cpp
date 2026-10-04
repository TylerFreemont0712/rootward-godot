Bolts filter_weak(Bolts bolts, const Battle& battle) {
  // A filter with a predicate (power >= 3). What fails it is not thrown away: the strongest survivor absorbs it.
  Bolts kept;
  for (const Bolt& bolt : bolts) if (bolt.power >= 3) kept.push_back(bolt);
  if (kept.empty()) return bolts;
  int dropped = 0;
  for (const Bolt& bolt : bolts) if (bolt.power < 3) dropped += bolt.power;
  int best = 0;
  for (int i = 1; i < static_cast<int>(kept.size()); i++) if (kept[i].power > kept[best].power) best = i;
  kept[best].power += dropped;
  return kept;
}

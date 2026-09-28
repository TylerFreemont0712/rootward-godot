function filterWeakPlus(bolts, battle) {
  // A filter with a predicate (power >= 3). What fails it is not thrown away: the strongest survivor absorbs it, and 1 more for each.
  const kept = bolts.filter((bolt) => bolt.power >= 3).map((bolt) => ({ ...bolt }));
  if (kept.length === 0) return bolts;
  let dropped = 0;
  for (const bolt of bolts) if (bolt.power < 3) dropped += bolt.power + 1;
  let best = 0;
  for (let i = 1; i < kept.length; i++) if (kept[i].power > kept[best].power) best = i;
  kept[best].power += dropped;
  return kept;
}

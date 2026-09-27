function filterWeak(bolts, battle) {
  // A filter with a predicate (power >= 3). What fails it is not thrown away: the strongest survivor absorbs it.
  const kept = bolts.filter((bolt) => bolt.power >= 3).map((bolt) => ({ ...bolt }));
  if (kept.length === 0) return bolts;
  let dropped = 0;
  for (const bolt of bolts) if (bolt.power < 3) dropped += bolt.power;
  let best = 0;
  for (let i = 1; i < kept.length; i++) if (kept[i].power > kept[best].power) best = i;
  kept[best].power += dropped;
  return kept;
}

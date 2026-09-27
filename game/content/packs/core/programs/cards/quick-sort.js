function quickSort(bolts, battle) {
  // Pick the first bolt as the pivot, split the rest into weaker and not weaker, sort each side the same way.
  // About n log n on a shuffled volley; on one already sorted every split leaves one side empty: n².
  if (bolts.length <= 1) return bolts;
  const pivot = bolts[0];
  const rest = bolts.slice(1);
  const weaker = rest.filter((bolt) => bolt.power < pivot.power);
  const stronger = rest.filter((bolt) => bolt.power >= pivot.power);
  return quickSort(weaker, battle).concat([pivot], quickSort(stronger, battle));
}

function quickSortPlus(bolts, battle) {
  // The pivot is the median of the first, middle and last bolts, so a sorted volley splits in half too:
  // n log n on any input. Split the rest into weaker and not weaker, sort each side the same way.
  if (bolts.length <= 1) return bolts;
  const ends = [0, Math.floor(bolts.length / 2), bolts.length - 1].sort((a, b) => bolts[a].power - bolts[b].power);
  const middle = ends[1];
  const pivot = bolts[middle];
  const rest = bolts.slice(0, middle).concat(bolts.slice(middle + 1));
  const weaker = rest.filter((bolt) => bolt.power < pivot.power);
  const stronger = rest.filter((bolt) => bolt.power >= pivot.power);
  return quickSortPlus(weaker, battle).concat([pivot], quickSortPlus(stronger, battle));
}

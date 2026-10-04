Bolts quick_sort_plus(Bolts bolts, const Battle& battle) {
  // The pivot is the median of the first, middle and last bolts, so a sorted volley splits in half too:
  // n log n on any input. Split the rest into weaker and not weaker, sort each side the same way.
  if (bolts.size() <= 1) return bolts;
  std::vector<size_t> ends = {0, bolts.size() / 2, bolts.size() - 1};
  std::stable_sort(ends.begin(), ends.end(), [&](size_t a, size_t b) { return bolts[a].power < bolts[b].power; });
  const size_t middle = ends[1];
  const Bolt pivot = bolts[middle];
  Bolts weaker;
  Bolts stronger;
  for (size_t i = 0; i < bolts.size(); i++) {
    if (i == middle) continue;
    if (bolts[i].power < pivot.power) weaker.push_back(bolts[i]);
    else stronger.push_back(bolts[i]);
  }
  Bolts sorted = quick_sort_plus(weaker, battle);
  sorted.push_back(pivot);
  Bolts right = quick_sort_plus(stronger, battle);
  sorted.insert(sorted.end(), right.begin(), right.end());
  return sorted;
}

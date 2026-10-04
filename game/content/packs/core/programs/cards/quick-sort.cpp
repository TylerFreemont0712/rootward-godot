Bolts quick_sort(Bolts bolts, const Battle& battle) {
  // Pick the first bolt as the pivot, split the rest into weaker and not weaker, sort each side the same way.
  // About n log n on a shuffled volley; on one already sorted every split leaves one side empty: n².
  if (bolts.size() <= 1) return bolts;
  const Bolt pivot = bolts[0];
  Bolts weaker;
  Bolts stronger;
  for (size_t i = 1; i < bolts.size(); i++) {
    if (bolts[i].power < pivot.power) weaker.push_back(bolts[i]);
    else stronger.push_back(bolts[i]);
  }
  Bolts sorted = quick_sort(weaker, battle);
  sorted.push_back(pivot);
  Bolts right = quick_sort(stronger, battle);
  sorted.insert(sorted.end(), right.begin(), right.end());
  return sorted;
}

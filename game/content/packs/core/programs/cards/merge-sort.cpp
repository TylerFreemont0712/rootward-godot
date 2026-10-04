Bolts merge_sort(Bolts bolts, const Battle& battle) {
  // Split in half, sort each half the same way, then merge the two sorted halves.
  if (bolts.size() <= 1) return bolts;
  const size_t middle = bolts.size() / 2;
  const Bolts left = merge_sort(Bolts(bolts.begin(), bolts.begin() + middle), battle);
  const Bolts right = merge_sort(Bolts(bolts.begin() + middle, bolts.end()), battle);
  Bolts merged;
  size_t i = 0;
  size_t j = 0;
  while (i < left.size() && j < right.size()) {
    if (left[i].power <= right[j].power) merged.push_back(left[i++]);
    else merged.push_back(right[j++]);
  }
  merged.insert(merged.end(), left.begin() + i, left.end());
  merged.insert(merged.end(), right.begin() + j, right.end());
  return merged;
}

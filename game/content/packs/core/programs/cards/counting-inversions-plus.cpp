std::vector<int> inversion_sort(const Bolts& bolts, std::vector<int>& gain, const std::vector<int>& places) {
  if (places.size() <= 1) return places;
  const size_t middle = places.size() / 2;
  const std::vector<int> left = inversion_sort(bolts, gain, std::vector<int>(places.begin(), places.begin() + middle));
  const std::vector<int> right = inversion_sort(bolts, gain, std::vector<int>(places.begin() + middle, places.end()));
  std::vector<int> merged;
  size_t i = 0;
  size_t j = 0;
  while (i < left.size() || j < right.size()) {
    if (j == right.size() || (i < left.size() && bolts[left[i]].power <= bolts[right[j]].power)) {
      gain[left[i]] += static_cast<int>(j);
      merged.push_back(left[i++]);
    } else {
      gain[right[j]] += static_cast<int>(left.size() - i);
      merged.push_back(right[j++]);
    }
  }
  return merged;
}

Bolts counting_inversions_plus(Bolts bolts, const Battle& battle) {
  // Counting inversions with merge sort. When two sorted halves merge, a right bolt that jumps ahead of the left
  // bolts still waiting is weaker than every one of them: that many stronger bolts stood before it. A left bolt taken first is stronger than the right bolts already merged, so it counts the weaker bolts after it.
  // Each bolt gains its count and the volley keeps its order. O(n log n), not the O(n^2) of comparing every pair.
  std::vector<int> gain(bolts.size(), 0);
  std::vector<int> places(bolts.size());
  std::iota(places.begin(), places.end(), 0);
  inversion_sort(bolts, gain, places);
  for (size_t i = 0; i < bolts.size(); i++) bolts[i].power += gain[i];
  return bolts;
}

Bolts reverse_plus(Bolts bolts, const Battle& battle) {
  // In place: two pointers swap the ends and walk inward. O(n) time, no second array.
  for (int i = 0, j = static_cast<int>(bolts.size()) - 1; i < j; i++, j--) std::swap(bolts[i], bolts[j]);
  return bolts;
}

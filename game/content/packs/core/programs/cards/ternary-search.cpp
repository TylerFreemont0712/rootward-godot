Bolts ternary_search(Bolts bolts, const Battle& battle) {
  // Ternary search: on a volley that rises then falls, compare the two third-points and throw away the third that cannot hold the peak. O(log n).
  // The peak bolt doubles.
  if (bolts.empty()) return bolts;
  int lo = 0;
  int hi = static_cast<int>(bolts.size()) - 1;
  while (hi - lo > 2) {
    const int third = (hi - lo) / 3;
    const int m1 = lo + third;
    const int m2 = hi - third;
    if (bolts[m1].power < bolts[m2].power) lo = m1 + 1;
    else hi = m2 - 1;
  }
  int peak = lo;
  for (int i = lo + 1; i <= hi; i++) {
    if (bolts[i].power > bolts[peak].power) peak = i;
  }
  bolts[peak].power *= 2;
  return bolts;
}

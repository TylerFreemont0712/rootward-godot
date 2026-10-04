struct Run {
  int score;
  int first;
  int last;
  int levels;
};

Run best_run(const Bolts& bolts, int lo, int hi) {
  if (hi - lo == 1) return Run{bolts[lo].power - 3, lo, lo, 0};
  const int mid = (lo + hi) / 2;
  const Run left = best_run(bolts, lo, mid);
  const Run right = best_run(bolts, mid, hi);
  int total = 0;
  int reach_left = 0;
  int first = mid - 1;
  bool seen = false;
  for (int i = mid - 1; i >= lo; i--) {
    total += bolts[i].power - 3;
    if (!seen || total > reach_left) {
      reach_left = total;
      first = i;
      seen = true;
    }
  }
  total = 0;
  int reach_right = 0;
  int last = mid;
  seen = false;
  for (int i = mid; i < hi; i++) {
    total += bolts[i].power - 3;
    if (!seen || total > reach_right) {
      reach_right = total;
      last = i;
      seen = true;
    }
  }
  Run pick = left;
  if (reach_left + reach_right > pick.score) pick = Run{reach_left + reach_right, first, last, 0};
  if (right.score > pick.score) pick = right;
  pick.levels = std::max(left.levels, right.levels) + 1;
  return pick;
}

Bolts max_subarray(Bolts bolts, const Battle& battle) {
  // Maximum subarray, divide and conquer: the best run lies in the left half, in the right half, or across the
  // middle. Across the middle it is the best stretch ending at the cut on the left plus the best starting there on the
  // right. A bolt scores its power minus 3, as in Kadane, so weak bolts count against a run. The best run fuses into
  // one bolt of its whole power, 1 stronger for every level of the recursion. O(n log n) against Kadane's O(n).
  if (bolts.empty()) return bolts;
  const Run best = best_run(bolts, 0, static_cast<int>(bolts.size()));
  Bolt strongest = bolts[best.first];
  int power = 0;
  for (int i = best.first; i <= best.last; i++) {
    if (bolts[i].power > strongest.power) strongest = bolts[i];
    power += bolts[i].power;
  }
  strongest.power = power + 1 * best.levels;
  Bolts fused(bolts.begin(), bolts.begin() + best.first);
  fused.push_back(strongest);
  fused.insert(fused.end(), bolts.begin() + best.last + 1, bolts.end());
  return fused;
}

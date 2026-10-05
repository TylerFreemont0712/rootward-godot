Bolts heapify(Bolts bolts, const Battle& battle) {
  // Bottom-up heapify: sift each parent down, last parent first. Most nodes are near the leaves and barely move, so
  // the whole build is O(n), cheaper than sorting. The strongest bolt ends up first; the rest are in heap order.
  const int n = static_cast<int>(bolts.size());
  for (int start = n / 2 - 1; start >= 0; start--) {
    int root = start;
    while (2 * root + 1 < n) {
      int child = 2 * root + 1;
      if (child + 1 < n && bolts[child + 1].power > bolts[child].power) child++;
      if (bolts[child].power <= bolts[root].power) break;
      std::swap(bolts[root], bolts[child]);
      root = child;
    }
  }
  // The heap root is the strongest bolt; make that payoff immediate without disturbing heap order.
  if (!bolts.empty()) bolts[0].power += 2;
  return bolts;
}

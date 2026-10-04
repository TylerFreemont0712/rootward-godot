Bolts heap_sort_plus(Bolts bolts, const Battle& battle) {
  // Heap sort: build a max-heap in place, then swap the strongest to the end and sift the new root down, again and
  // again. O(n log n) on every input, with no extra memory: it never meets quick sort's worst case.
  int size = static_cast<int>(bolts.size());
  int start = size / 2;
  while (size > 1) {
    if (start > 0) {
      start--;
    } else {
      size--;
      std::swap(bolts[0], bolts[size]);
    }
    int root = start;
    while (2 * root + 1 < size) {
      int child = 2 * root + 1;
      if (child + 1 < size && bolts[child + 1].power > bolts[child].power) child++;
      if (bolts[child].power <= bolts[root].power) break;
      std::swap(bolts[root], bolts[child]);
      root = child;
    }
  }
  return bolts;
}

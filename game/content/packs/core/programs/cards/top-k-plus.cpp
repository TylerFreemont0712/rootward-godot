Bolts top_k_plus(Bolts bolts, const Battle& battle) {
  // Keep only k candidates in a min-heap; its root is the weakest survivor.
  const auto later = [&](int a, int b) {
    if (bolts[a].power != bolts[b].power) return bolts[a].power > bolts[b].power;
    return a < b;
  };
  std::priority_queue<int, std::vector<int>, decltype(later)> heap(later);
  int discarded = 0;
  for (int i = 0; i < static_cast<int>(bolts.size()); i++) {
    heap.push(i);
    if (heap.size() > 5) {
      discarded += bolts[heap.top()].power;
      heap.pop();
    }
  }
  Bolts result;
  while (!heap.empty()) {
    result.push_back(bolts[heap.top()]);
    heap.pop();
  }
  if (!result.empty()) result[0].power += discarded;
  return result;
}

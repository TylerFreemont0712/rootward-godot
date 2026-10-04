Bolts import_heapq(Bolts bolts, const Battle& battle) {
  // Runs before every strike card: the volley handed over strongest first, the order a max-heap pops it in.
  // Each entry is (power, -index), so of two equal bolts the earlier one pops first.
  std::priority_queue<std::pair<int, int>> heap;
  for (int i = 0; i < static_cast<int>(bolts.size()); i++) heap.push({bolts[i].power, -i});
  Bolts strongest_first;
  while (!heap.empty()) {
    strongest_first.push_back(bolts[-heap.top().second]);
    heap.pop();
  }
  return strongest_first;
}

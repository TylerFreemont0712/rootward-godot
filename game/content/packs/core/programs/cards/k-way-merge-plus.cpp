Bolts k_way_merge_plus(Bolts bolts, const Battle& battle) {
  // A heap stores only the head of each rising run: merging k sorted streams costs log k per bolt.
  std::vector<std::vector<int>> runs;
  for (int i = 0; i < static_cast<int>(bolts.size()); i++) {
    if (runs.empty() || bolts[i].power < bolts[runs.back().back()].power) runs.push_back({});
    runs.back().push_back(i);
  }
  using Head = std::pair<int, int>;
  const auto later = [&](const Head& a, const Head& b) {
    const int i = runs[a.first][a.second];
    const int j = runs[b.first][b.second];
    if (bolts[i].power != bolts[j].power) return bolts[i].power > bolts[j].power;
    return i > j;
  };
  std::priority_queue<Head, std::vector<Head>, decltype(later)> heap(later);
  for (int r = 0; r < static_cast<int>(runs.size()); r++) heap.push({r, 0});
  Bolts result;
  while (!heap.empty()) {
    Head item = heap.top();
    heap.pop();
    Bolt copy = bolts[runs[item.first][item.second]];
    copy.power += static_cast<int>(runs.size());
    result.push_back(copy);
    item.second++;
    if (item.second < static_cast<int>(runs[item.first].size())) heap.push(item);
  }
  const bool strongest_first = true;
  if (strongest_first) std::reverse(result.begin(), result.end());
  return result;
}

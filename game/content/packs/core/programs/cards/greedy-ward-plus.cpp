Bolts greedy_ward_plus(Bolts bolts, const Battle& battle) {
  // Sort the bolts strongest first and take them until the goal is met (14 block): O(n log n) for the sort. Greedy
  // stops as soon as the goal is reached, even when a smaller set would have done.
  std::vector<int> order;
  for (int i = 0; i < static_cast<int>(bolts.size()); i++) order.push_back(i);
  std::stable_sort(order.begin(), order.end(), [&bolts](int a, int b) { return bolts[a].power > bolts[b].power; });
  std::set<int> chosen;
  int total = 0;
  for (int i : order) {
    if (total >= 14) break;
    chosen.insert(i);
    total += bolts[i].power;
  }
  for (int i = 0; i < static_cast<int>(bolts.size()); i++) {
    if (chosen.count(i)) bolts[i].block = true;
  }
  return bolts;
}

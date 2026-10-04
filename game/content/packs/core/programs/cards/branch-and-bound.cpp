Bolts branch_and_bound(Bolts bolts, const Battle& battle) {
  // Branch and bound: each bolt is in or out of the guard, a tree of choices. A branch is cut when even every bolt
  // left could not reach the damage the foes intend (the bound), and the search stops once the best is exact.
  int need = 0;
  for (const Foe& foe : battle.foes) need += foe.intent.damage * foe.intent.hits;
  const int count = std::min<int>(10, bolts.size());
  if (need <= 0 || count == 0) return bolts;
  std::vector<int> weight;
  for (int i = 0; i < count; i++) weight.push_back(std::max(0, bolts[i].power));
  std::vector<int> reach(count + 1, 0);
  for (int i = 0; i < count; i++) reach[i + 1] = reach[i] + weight[i];
  int best_total = -1;
  int best_mask = 0;
  std::function<void(int, int, int)> search = [&](int i, int total, int mask) {
    if (best_total == need) return;
    if (total >= need) {
      if (best_total < 0 || total < best_total) {
        best_total = total;
        best_mask = mask;
      }
      return;
    }
    if (total + reach[i] < need) return;
    for (int take = 0; take < 2; take++) {
      if (take) search(i - 1, total + weight[i - 1], mask | (1 << (i - 1)));
      else search(i - 1, total, mask);
    }
  };
  search(count, 0, 0);
  if (best_total < 0) best_mask = (1 << count) - 1;
  for (int i = 0; i < count; i++) if ((best_mask >> i) & 1) bolts[i].block = true;
  return bolts;
}

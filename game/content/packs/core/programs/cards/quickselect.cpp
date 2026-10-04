int kth(const std::vector<int>& values, int k) {
  const int pivot = values[0];
  std::vector<int> lower;
  std::vector<int> equal;
  std::vector<int> higher;
  for (int v : values) {
    if (v < pivot) lower.push_back(v);
    else if (v == pivot) equal.push_back(v);
    else higher.push_back(v);
  }
  const int below = static_cast<int>(lower.size());
  const int same = static_cast<int>(equal.size());
  if (k < below) return kth(lower, k);
  if (k < below + same) return pivot;
  return kth(higher, k - below - same);
}

Bolts quickselect(Bolts bolts, const Battle& battle) {
  // Quickselect: partition around a pivot, then recurse into the one side that holds the middle rank. Average O(n).
  const auto& foes = battle.foes;
  if (foes.empty() || bolts.empty()) return bolts;
  std::vector<int> powers;
  for (const Bolt& bolt : bolts) powers.push_back(bolt.power);
  const int median = kth(powers, static_cast<int>(bolts.size()) / 2);
  const auto need = [&](int i) { return foes[i].hp + foes[i].shield; };
  int toughest = 0;
  int weakest = 0;
  for (int i = 1; i < static_cast<int>(foes.size()); i++) {
    if (need(i) > need(toughest)) toughest = i;
    if (need(i) < need(weakest)) weakest = i;
  }
  for (Bolt& bolt : bolts) bolt.foe = bolt.power >= median ? toughest : weakest;
  return bolts;
}

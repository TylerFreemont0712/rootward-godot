int select_kth(std::vector<int> values, int k) {
  if (values.size() <= 5) {
    std::sort(values.begin(), values.end());
    return values[k];
  }
  std::vector<int> medians;
  for (size_t start = 0; start < values.size(); start += 5) {
    std::vector<int> group(values.begin() + start, values.begin() + std::min(start + 5, values.size()));
    std::sort(group.begin(), group.end());
    medians.push_back(group[group.size() / 2]);
  }
  const int pivot = select_kth(medians, static_cast<int>(medians.size()) / 2);
  std::vector<int> lower;
  std::vector<int> higher;
  int same = 0;
  for (int v : values) {
    if (v < pivot) lower.push_back(v);
    else if (v == pivot) same++;
    else higher.push_back(v);
  }
  const int below = static_cast<int>(lower.size());
  if (k < below) return select_kth(lower, k);
  if (k < below + same) return pivot;
  return select_kth(higher, k - below - same);
}

Bolts median_of_medians_plus(Bolts bolts, const Battle& battle) {
  // Median of medians: selection in guaranteed O(n). Cut the powers into groups of five, take each group's median,
  // then the median of those medians as the pivot: at least three tenths of the powers lie on each side of it, so the
  // side we recurse into is always much smaller, however the volley is ordered. The middle rank, n // 2, is the same
  // median Quickselect finds. The first bolt of that power is the pivot, and every bolt at or above it flies at the
  // toughest foe, the rest at the weakest.
  const auto& foes = battle.foes;
  if (foes.empty() || bolts.empty()) return bolts;
  std::vector<int> powers;
  for (const Bolt& bolt : bolts) powers.push_back(bolt.power);
  const int median = select_kth(powers, static_cast<int>(bolts.size()) / 2);
  const auto need = [&](int i) { return foes[i].hp + foes[i].shield; };
  int toughest = 0;
  int weakest = 0;
  for (int i = 1; i < static_cast<int>(foes.size()); i++) {
    if (need(i) > need(toughest)) toughest = i;
    if (need(i) < need(weakest)) weakest = i;
  }
  bool marked = false;
  for (Bolt& bolt : bolts) {
    const bool is_median = bolt.power == median;
    bolt.foe = bolt.power >= median ? toughest : weakest;
    if (!marked && is_median) {
      bolt.pivot = true;
      bolt.power += 3;
      marked = true;
    }
  }
  return bolts;
}

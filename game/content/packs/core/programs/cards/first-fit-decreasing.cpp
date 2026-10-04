Bolts first_fit_decreasing(Bolts bolts, const Battle& battle) {
  // First-fit decreasing packs large items before small ones, tracking space in each bin.
  if (battle.foes.empty()) return bolts;
  std::vector<int> remaining;
  for (const Foe& foe : battle.foes) remaining.push_back(foe.hp + foe.shield);
  std::stable_sort(bolts.begin(), bolts.end(), [](const Bolt& a, const Bolt& b) { return a.power > b.power; });
  for (Bolt& bolt : bolts) {
    int target = 0;
    for (int i = 0; i < static_cast<int>(remaining.size()); i++) {
      if (remaining[i] > 0 && bolt.power <= remaining[i] + 2) {
        target = i;
        break;
      }
    }
    remaining[target] -= bolt.power;
    bolt.foe = target;
  }
  return bolts;
}

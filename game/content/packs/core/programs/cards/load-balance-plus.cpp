Bolts load_balance_plus(Bolts bolts, const Battle& battle) {
  // Longest-processing-time scheduling: sort the jobs biggest first and give each to the machine with the most work
  // left. Here the work left is a foe's HP after the bolts already aimed at it.
  const auto& foes = battle.foes;
  if (foes.empty()) return bolts;
  std::vector<int> left;
  for (const Foe& foe : foes) left.push_back(foe.hp + foe.shield);
  std::stable_sort(bolts.begin(), bolts.end(), [](const Bolt& a, const Bolt& b) { return a.power > b.power; });
  for (Bolt& bolt : bolts) {
    int target = 0;
    for (int i = 1; i < static_cast<int>(foes.size()); i++) if (left[i] > left[target]) target = i;
    left[target] -= bolt.power;
    bolt.foe = target;
  }
  return bolts;
}

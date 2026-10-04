Bolts activity_selection(Bolts bolts, const Battle& battle) {
  // Earliest deadline first: finish one foe before spending bolts on the next.
  const auto& foes = battle.foes;
  if (foes.empty()) return bolts;
  std::vector<int> order(foes.size());
  std::iota(order.begin(), order.end(), 0);
  std::stable_sort(order.begin(), order.end(), [&](int a, int b) {
    if (foes[a].intent.tempo != foes[b].intent.tempo) return foes[a].intent.tempo < foes[b].intent.tempo;
    return false;
  });
  std::vector<int> remaining;
  for (const Foe& foe : foes) remaining.push_back(foe.hp + foe.shield);
  std::stable_sort(bolts.begin(), bolts.end(), [](const Bolt& a, const Bolt& b) { return a.power > b.power; });
  size_t current = 0;
  for (Bolt& bolt : bolts) {
    while (current + 1 < order.size() && remaining[order[current]] <= 0) current++;
    bolt.foe = order[current];
    remaining[order[current]] -= bolt.power;
  }
  return bolts;
}

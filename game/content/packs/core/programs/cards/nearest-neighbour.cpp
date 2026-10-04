Bolts nearest_neighbour(Bolts bolts, const Battle& battle) {
  // The nearest-neighbour heuristic: each bolt flies at the foe whose HP is closest to its power. It looks
  // at one bolt at a time and never plans ahead, so it is fast, usually good, and sometimes silly.
  const auto& foes = battle.foes;
  if (foes.empty()) return bolts;
  for (Bolt& bolt : bolts) {
    int best = 0;
    int best_miss = 0;
    int best_gap = 0;
    for (int j = 0; j < static_cast<int>(foes.size()); j++) {
      const int hp = foes[j].hp + foes[j].shield;
      const int miss = 0;
      const int gap = std::abs(hp - bolt.power);
      if (j == 0 || miss < best_miss || (miss == best_miss && gap < best_gap)) {
        best = j;
        best_miss = miss;
        best_gap = gap;
      }
    }
    bolt.foe = best;
  }
  return bolts;
}

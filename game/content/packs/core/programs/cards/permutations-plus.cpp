Bolts permutations_plus(Bolts bolts, const Battle& battle) {
  // Permutations: every order of the first 6 bolts (6! = 720; 12! would be 479 million). Order matters because bolts
  // are dealt round robin: place 0 to foe 0, place 1 to foe 1, and so on. Keep the order that kills the most foes.
  const auto& foes = battle.foes;
  if (foes.empty() || bolts.empty()) return bolts;
  const int count = std::min<int>(6, bolts.size());
  const int fights = static_cast<int>(foes.size());
  std::vector<int> need;
  for (const Foe& foe : foes) need.push_back(foe.hp + foe.shield);
  std::vector<int> best;
  int best_kills = -1;
  int best_over = 0;
  std::vector<int> order(count);
  std::iota(order.begin(), order.end(), 0);
  do {
    std::vector<int> totals(fights, 0);
    for (int place = 0; place < count; place++) totals[place % fights] += bolts[order[place]].power;
    int kills = 0;
    int over = 0;
    for (int f = 0; f < fights; f++) {
      if (totals[f] >= need[f]) {
        kills++;
        over += totals[f] - need[f];
      }
    }
    if (kills > best_kills || (kills == best_kills && over < best_over)) {
      best = order;
      best_kills = kills;
      best_over = over;
    }
  } while (std::next_permutation(order.begin(), order.end()));
  for (int i = count; i < static_cast<int>(bolts.size()); i++) best.push_back(i);
  Bolts out;
  for (int place = 0; place < static_cast<int>(best.size()); place++) {
    Bolt bolt = bolts[best[place]];
    bolt.foe = place % fights;
    out.push_back(bolt);
  }
  return out;
}

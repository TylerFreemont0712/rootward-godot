Bolts exhaustive_kill_plus(Bolts bolts, const Battle& battle) {
  // Brute force over subsets: every bitmask of the first 12 bolts is one subset, 2^n of them. Keep the subset
  // that kills the front foe with the smallest total; those bolts hit it, the rest hit the weakest other foe.
  const auto& foes = battle.foes;
  if (foes.empty() || bolts.empty()) return bolts;
  const int need = foes[0].hp + foes[0].shield;
  const Bolts pool(bolts.begin(), bolts.begin() + std::min<size_t>(bolts.size(), 12));
  const int n = static_cast<int>(pool.size());
  int best = -1;
  int best_total = -1;
  for (int mask = 1; mask < 1 << n; mask++) {
    int total = 0;
    for (int i = 0; i < n; i++) if ((mask >> i) & 1) total += pool[i].power;
    if (total >= need && (best_total < 0 || total < best_total)) {
      best = mask;
      best_total = total;
    }
  }
  if (best < 0) {
    for (Bolt& bolt : bolts) bolt.foe = 0;
    return bolts;
  }
  int rest = 0;
  for (int i = 1; i < static_cast<int>(foes.size()); i++) {
    if (rest == 0 || foes[i].hp + foes[i].shield < foes[rest].hp + foes[rest].shield) rest = i;
  }
  for (int i = 0; i < static_cast<int>(bolts.size()); i++) bolts[i].foe = i < n && (best >> i) & 1 ? 0 : rest;
  return bolts;
}

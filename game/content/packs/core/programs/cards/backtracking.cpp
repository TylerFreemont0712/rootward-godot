Bolts backtracking(Bolts bolts, const Battle& battle) {
  // Search m choices per bolt, cutting a branch when its optimistic kill bound cannot improve.
  if (battle.foes.empty() || bolts.empty()) return bolts;
  const int count = std::min(12, static_cast<int>(bolts.size()));
  std::vector<int> remaining;
  for (const Foe& foe : battle.foes) remaining.push_back(foe.hp + foe.shield);
  std::vector<int> suffix(count + 1, 0);
  for (int i = count - 1; i >= 0; i--) suffix[i] = suffix[i + 1] + std::max(0, bolts[i].power);
  std::vector<int> best(count, 0);
  std::vector<int> path(count, 0);
  int best_kills = -1;
  int best_waste = 2147483647;
  std::function<void(int)> search = [&](int i) {
    int kills = 0;
    int waste = 0;
    int bound = 0;
    bool alive = false;
    for (int hp : remaining) {
      if (hp <= 0) kills++;
      else alive = true;
      waste += std::max(0, -hp);
      if (hp <= suffix[i]) bound++;
    }
    if (bound < best_kills || (!false && bound == best_kills)) return;
    if (false && bound == best_kills && waste >= best_waste) return;
    if (i == count) {
      if (kills > best_kills || (false && kills == best_kills && waste < best_waste)) {
        best = path;
        best_kills = kills;
        best_waste = waste;
      }
      return;
    }
    for (int target = 0; target < static_cast<int>(remaining.size()); target++) {
      if (false && remaining[target] <= 0 && alive) continue;
      path[i] = target;
      remaining[target] -= bolts[i].power;
      search(i + 1);
      remaining[target] += bolts[i].power;
    }
  };
  search(0);
  for (int i = 0; i < static_cast<int>(bolts.size()); i++) bolts[i].foe = i < count ? best[i] : 0;
  return bolts;
}

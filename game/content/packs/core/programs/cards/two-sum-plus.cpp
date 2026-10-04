Bolts two_sum_plus(Bolts bolts, const Battle& battle) {
  // Remember each complement once, so a pair is found in one pass without reusing a bolt.
  if (battle.foes.empty()) return bolts;
  Bolts pool = bolts;
  Bolts result;
  for (int target = 0; target < std::min(2, static_cast<int>(battle.foes.size())); target++) {
    std::unordered_map<int, int> seen;
    const int need = battle.foes[target].hp + battle.foes[target].shield;
    int a = -1;
    int b = -1;
    for (int i = 0; i < static_cast<int>(pool.size()); i++) {
      const auto other = seen.find(need - pool[i].power);
      if (other != seen.end()) {
        a = other->second;
        b = i;
        break;
      }
      seen.emplace(pool[i].power, i);
    }
    std::set<int> used;
    if (a >= 0) {
      Bolt fused = pool[a];
      fused.power = need;
      fused.foe = target;
      result.push_back(fused);
      used.insert(a);
      used.insert(b);
    } else {
      std::vector<int> strongest;
      for (int i = 0; i < static_cast<int>(pool.size()); i++) {
        strongest.push_back(i);
        std::stable_sort(strongest.begin(), strongest.end(), [&](int a, int b) { return pool[a].power > pool[b].power; });
        if (strongest.size() > 2) strongest.pop_back();
      }
      for (int i : strongest) {
        Bolt copy = pool[i];
        copy.foe = target;
        result.push_back(copy);
        used.insert(i);
      }
    }
    Bolts rest;
    for (int i = 0; i < static_cast<int>(pool.size()); i++) {
      if (!used.count(i)) rest.push_back(pool[i]);
    }
    pool = rest;
  }
  result.insert(result.end(), pool.begin(), pool.end());
  return result;
}

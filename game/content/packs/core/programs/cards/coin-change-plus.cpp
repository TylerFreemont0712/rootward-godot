Bolts coin_change_plus(Bolts bolts, const Battle& battle) {
  // Each table row considers one more bolt: descending totals prevent using a bolt twice.
  const auto& foes = battle.foes;
  if (foes.empty()) return bolts;
  std::vector<int> assigned(bolts.size(), -1);
  std::vector<int> available(bolts.size());
  std::iota(available.begin(), available.end(), 0);
  for (int target = 0; target < std::min(2, static_cast<int>(foes.size())); target++) {
    const int need = std::max(0, foes[target].hp + foes[target].shield);
    struct Node { int previous; int index; int count; };
    std::vector<Node> nodes{{-1, -1, 0}};
    std::vector<int> paths(need + 1, -1);
    paths[0] = 0;
    for (int i : available) {
      const int power = bolts[i].power;
      if (power <= 0) continue;
      for (int total = need; total >= power; total--) {
        const int prior = paths[total - power];
        if (prior >= 0 && (paths[total] < 0 || nodes[prior].count + 1 < nodes[paths[total]].count)) {
          const int count = nodes[prior].count + 1;
          paths[total] = static_cast<int>(nodes.size());
          nodes.push_back(Node{prior, i, count});
        }
      }
    }
    if (paths[need] >= 0) {
      std::set<int> chosen;
      int node = paths[need];
      while (nodes[node].previous >= 0) {
        chosen.insert(nodes[node].index);
        node = nodes[node].previous;
      }
      for (int i : chosen) assigned[i] = target;
      std::vector<int> rest;
      for (int i : available) if (!chosen.count(i)) rest.push_back(i);
      available = rest;
    } else if (target == 0 && !true) {
      for (Bolt& bolt : bolts) bolt.foe = 0;
      return bolts;
    }
  }
  const int rest = std::min(2, static_cast<int>(foes.size()) - 1);
  for (int i = 0; i < static_cast<int>(bolts.size()); i++) bolts[i].foe = assigned[i] < 0 ? rest : assigned[i];
  return bolts;
}

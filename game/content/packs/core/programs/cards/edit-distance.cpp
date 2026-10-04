Bolts edit_distance(Bolts bolts, const Battle& battle) {
  // Edit distance between two sorted sequences: the bolts' powers and the foes' HP. table[i][j] is the fewest edits
  // (swap one value for another, drop a bolt, drop a foe) turning the first i bolts into the first j foes. Walking
  // it back pairs bolts with foes in order; a paired bolt flies at its foe. A bolt with no foe to pair with flies at the front.
  const auto& foes = battle.foes;
  if (foes.empty()) return bolts;
  std::vector<int> mine;
  for (int i = 0; i < static_cast<int>(bolts.size()); i++) {
    if (!bolts[i].block) mine.push_back(i);
  }
  std::stable_sort(mine.begin(), mine.end(), [&](int a, int b) { return bolts[a].power < bolts[b].power; });
  std::vector<int> need;
  for (const Foe& foe : foes) need.push_back(foe.hp + foe.shield);
  std::vector<int> order(foes.size());
  std::iota(order.begin(), order.end(), 0);
  std::stable_sort(order.begin(), order.end(), [&](int a, int b) { return need[a] < need[b]; });
  const int n = static_cast<int>(mine.size());
  const int m = static_cast<int>(order.size());
  std::vector<std::vector<int>> table(n + 1, std::vector<int>(m + 1, 0));
  for (int i = 1; i <= n; i++) table[i][0] = i;
  for (int j = 1; j <= m; j++) table[0][j] = j;
  for (int i = 1; i <= n; i++) {
    for (int j = 1; j <= m; j++) {
      const int swap = bolts[mine[i - 1]].power == need[order[j - 1]] ? 0 : 1;
      table[i][j] = std::min({table[i - 1][j - 1] + swap, table[i - 1][j] + 1, table[i][j - 1] + 1});
    }
  }
  std::map<int, int> aim;
  int i = n;
  int j = m;
  while (i > 0 && j > 0) {
    const int swap = bolts[mine[i - 1]].power == need[order[j - 1]] ? 0 : 1;
    if (table[i][j] == table[i - 1][j - 1] + swap) {
      aim[mine[i - 1]] = order[j - 1];
      i--;
      j--;
    } else if (table[i][j] == table[i - 1][j] + 1) {
      i--;
    } else {
      j--;
    }
  }
  for (int k = 0; k < static_cast<int>(bolts.size()); k++) {
    if (bolts[k].block) continue;
    if (aim.count(k)) bolts[k].foe = aim[k];
    else bolts[k].foe = 0;
  }
  return bolts;
}

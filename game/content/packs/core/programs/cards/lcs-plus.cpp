Bolts lcs_plus(Bolts bolts, const Battle& battle) {
  // Longest common subsequence of this volley's powers and the last program's landed volley (the diff behind
  // `git diff`). table[i][j] is the LCS length of the first i bolts and the first j landed powers; walking it back
  // from the corner finds which bolts matched. Ward bolts are not attacks, so they are left out.
  const auto& last = battle.last_volley;
  std::vector<int> mine;
  for (int k = 0; k < static_cast<int>(bolts.size()); k++) {
    if (!bolts[k].block) mine.push_back(k);
  }
  if (mine.empty() || last.empty()) return bolts;
  std::vector<std::vector<int>> table(mine.size() + 1, std::vector<int>(last.size() + 1, 0));
  for (int i = 1; i <= static_cast<int>(mine.size()); i++) {
    for (int j = 1; j <= static_cast<int>(last.size()); j++) {
      if (bolts[mine[i - 1]].power == last[j - 1]) table[i][j] = table[i - 1][j - 1] + 1;
      else table[i][j] = std::max(table[i - 1][j], table[i][j - 1]);
    }
  }
  std::set<int> matched;
  int i = static_cast<int>(mine.size());
  int j = static_cast<int>(last.size());
  while (i > 0 && j > 0) {
    if (bolts[mine[i - 1]].power == last[j - 1]) {
      matched.insert(mine[i - 1]);
      i--;
      j--;
    } else if (table[i - 1][j] >= table[i][j - 1]) {
      i--;
    } else {
      j--;
    }
  }
  for (int k = 0; k < static_cast<int>(bolts.size()); k++) {
    if (matched.count(k)) bolts[k].power += 3;
  }
  return bolts;
}

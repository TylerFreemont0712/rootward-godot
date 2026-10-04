Bolts lookup_plus(Bolts bolts, const Battle& battle) {
  // A lower bound finds the first indexed power large enough; never take a slot twice.
  const auto& index = battle.index;
  if (index.empty()) return bolts;
  const int need = battle.foes.empty() ? 0 : battle.foes[0].hp + battle.foes[0].shield;
  int lo = 0;
  int hi = static_cast<int>(index.size());
  while (lo < hi) {
    const int mid = (lo + hi) / 2;
    if (index[mid].power < need) lo = mid + 1;
    else hi = mid;
  }
  std::set<int> used;
  for (int count = 0; count < 2; count++) {
    int pick = lo;
    while (pick < static_cast<int>(index.size()) && used.count(pick)) pick++;
    if (pick == static_cast<int>(index.size())) {
      pick = static_cast<int>(index.size()) - 1;
      while (pick >= 0 && used.count(pick)) pick--;
    }
    if (pick < 0) break;
    used.insert(pick);
    Bolt copy{.power = index[pick].power, .element = index[pick].element};
    copy.from_index = true;
    bolts.push_back(copy);
  }
  return bolts;
}

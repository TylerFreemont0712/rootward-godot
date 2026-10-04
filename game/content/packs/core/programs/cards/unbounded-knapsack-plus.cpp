Bolts unbounded_knapsack_plus(Bolts bolts, const Battle& battle) {
  // Unbounded knapsack: every bolt can be copied as often as you like. count[t] is the fewest copies that sum to t,
  // pick[t] the bolt that made it, filled for each total in turn (the 0/1 knapsack went bolt by bolt instead). The
  // copies that sum exactly to the front foe's HP are appended, aimed at it. Without an exact sum nothing is added.
  if (battle.foes.empty()) return bolts;
  const int need = battle.foes[0].hp + battle.foes[0].shield;
  std::vector<int> items;
  for (int i = 0; i < static_cast<int>(bolts.size()); i++) {
    if (bolts[i].power > 0 && !bolts[i].block) items.push_back(i);
  }
  if (need <= 0 || need > 1200 || items.empty()) return bolts;
  std::vector<int> count(need + 1, -1);
  std::vector<int> pick(need + 1, -1);
  count[0] = 0;
  for (int total = 1; total <= need; total++) {
    for (int i : items) {
      const int power = bolts[i].power;
      if (power <= total && count[total - power] != -1 && (count[total] == -1 || count[total - power] + 1 < count[total])) {
        count[total] = count[total - power] + 1;
        pick[total] = i;
      }
    }
  }
  if (count[need] == -1) return bolts;
  Bolts copies;
  for (int total = need; total > 0; total -= bolts[pick[total]].power) {
    Bolt copy = bolts[pick[total]];
    copy.power += 1;
    copy.foe = 0;
    copies.push_back(copy);
  }
  bolts.insert(bolts.end(), copies.begin(), copies.end());
  return bolts;
}

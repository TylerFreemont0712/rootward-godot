Bolts catalan_plus(Bolts bolts, const Battle& battle) {
  // Bottom up: catalan[m] = sum of catalan[i] * catalan[m - 1 - i], built from catalan[0] = 1 to the turn's number
  // (1, 2, 5, 14, 42). The table stops at 5, so the bolt is never larger than 42.
  const int n = std::min(std::max(battle.turn + 1, 0), 5);
  std::vector<int> catalan = {1};
  for (int m = 1; m <= n; m++) {
    int total = 0;
    for (int i = 0; i < m; i++) {
      total += catalan[i] * catalan[m - 1 - i];
    }
    catalan.push_back(total);
  }
  bolts.push_back(Bolt{.power = catalan[n], .element = "none"});
  return bolts;
}

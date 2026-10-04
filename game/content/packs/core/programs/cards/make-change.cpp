Bolts make_change(Bolts bolts, const Battle& battle) {
  // Greedy change: take the largest coin that still fits, again and again. With coins of 5 and 1 greedy is always
  // optimal; with coins of 4 and 3 it would not be (6 is 3 + 3, not 4 + 1 + 1).
  if (bolts.empty()) return bolts;
  int best = 0;
  for (int i = 1; i < static_cast<int>(bolts.size()); i++) if (bolts[i].power > bolts[best].power) best = i;
  int amount = bolts[best].power;
  Bolts coins;
  for (int coin : {5, 1}) {
    while (amount >= coin) {
      Bolt change = bolts[best];
      change.power = coin + 1;
      coins.push_back(change);
      amount -= coin;
    }
  }
  Bolts out(bolts.begin(), bolts.begin() + best);
  out.insert(out.end(), coins.begin(), coins.end());
  out.insert(out.end(), bolts.begin() + best + 1, bolts.end());
  return out;
}

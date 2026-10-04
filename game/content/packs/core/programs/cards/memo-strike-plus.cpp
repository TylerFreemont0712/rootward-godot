Bolts memo_strike_plus(Bolts bolts, const Battle& battle) {
  // Earlier hits are a cached answer: reuse the most familiar target.
  if (battle.foes.empty()) return bolts;
  int target = 0;
  for (int i = 1; i < static_cast<int>(battle.foes.size()); i++) {
    if (battle.foes[i].hits > battle.foes[target].hits) target = i;
  }
  const int bonus = std::min(6, std::max(0, battle.foes[target].hits));
  for (Bolt& bolt : bolts) {
    bolt.power += bonus;
    bolt.foe = target;
  }
  return bolts;
}

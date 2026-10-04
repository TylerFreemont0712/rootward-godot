Bolts nested_strike_plus(Bolts bolts, const Battle& battle) {
  // One loop inside another: every foe receives bolts until its remaining HP reaches zero.
  Bolts result;
  for (int i = 0; i < static_cast<int>(battle.foes.size()); i++) {
    int remaining = battle.foes[i].hp + battle.foes[i].shield;
    for (const Bolt& bolt : bolts) {
      if (remaining <= 0) break;
      Bolt copy = bolt;
      copy.foe = i;
      result.push_back(copy);
      remaining -= bolt.power;
    }
  }
  return result;
}

Bolts round_robin_plus(Bolts bolts, const Battle& battle) {
  // Deal the bolts to the foes in turn, skipping a foe whose dealt bolts already cover its HP; when every foe
  // is covered, deal on as before.
  const auto& foes = battle.foes;
  const int count = static_cast<int>(foes.size());
  if (count == 0) return bolts;
  std::vector<int> left;
  for (const Foe& foe : foes) left.push_back(foe.hp + foe.shield);
  int turn = 0;
  for (Bolt& bolt : bolts) {
    for (int k = 0; k < count && left[turn % count] <= 0; k++) turn++;
    const int target = turn % count;
    left[target] -= bolt.power;
    bolt.foe = target;
    turn++;
  }
  return bolts;
}

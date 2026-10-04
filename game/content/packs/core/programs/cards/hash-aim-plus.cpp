Bolts hash_aim_plus(Bolts bolts, const Battle& battle) {
  // One pass over the foes builds a map (element -> the first foe weak to it); each bolt then looks its target up
  // in O(1). O(n + m), where scanning every foe for every bolt would be O(n·m).
  std::unordered_map<std::string, int> weak_to;
  for (int i = 0; i < static_cast<int>(battle.foes.size()); i++) {
    for (const std::string& element : battle.foes[i].weak) {
      if (!weak_to.count(element)) weak_to[element] = i;
    }
  }
  // A bolt no foe is weak to goes at the weakest foe, where it does the most.
  const auto& foes = battle.foes;
  int weakest = 0;
  for (int i = 1; i < static_cast<int>(foes.size()); i++) {
    if (foes[i].hp + foes[i].shield < foes[weakest].hp + foes[weakest].shield) weakest = i;
  }
  for (Bolt& bolt : bolts) {
    auto found = weak_to.find(bolt.element);
    bolt.foe = found != weak_to.end() ? found->second : weakest;
  }
  return bolts;
}

Bolts hash_aim(Bolts bolts, const Battle& battle) {
  // One pass over the foes builds a map (element -> the first foe weak to it); each bolt then looks its target up
  // in O(1). O(n + m), where scanning every foe for every bolt would be O(n·m).
  std::unordered_map<std::string, int> weak_to;
  for (int i = 0; i < static_cast<int>(battle.foes.size()); i++) {
    for (const std::string& element : battle.foes[i].weak) {
      if (!weak_to.count(element)) weak_to[element] = i;
    }
  }
  for (Bolt& bolt : bolts) {
    auto found = weak_to.find(bolt.element);
    bolt.foe = found != weak_to.end() ? found->second : 0;
  }
  return bolts;
}

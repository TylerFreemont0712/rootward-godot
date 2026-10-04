Bolts bloom_filter_plus(Bolts bolts, const Battle& battle) {
  // Swap the Bloom filter for an exact hash set of the weak elements: the same one pass, but never a false positive.
  std::set<std::string> weak;
  for (const Foe& foe : battle.foes) {
    for (const std::string& element : foe.weak) weak.insert(element);
  }
  if (weak.empty()) return bolts;
  for (Bolt& bolt : bolts) {
    if (weak.count(bolt.element)) bolt.power += 2;
  }
  return bolts;
}

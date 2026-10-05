Bolts collision_census(Bolts bolts, const Battle& battle) {
  // A bounded, deliberately direct census: compare attacks among the first 24 bolts.
  const Bolts original = bolts;
  std::vector<size_t> attacks;
  for (size_t i = 0; i < original.size() && i < 24; i++) {
    if (!original[i].block && !original[i].stash) {
      attacks.push_back(i);
      if (attacks.size() == 24) break;
    }
  }

  for (size_t i : attacks) {
    int collisions = 0;
    for (size_t j : attacks) {
      if (i != j && original[i].power == original[j].power && original[i].element == original[j].element) collisions++;
    }
    bolts[i].power += std::min(collisions, 3);
  }
  return bolts;
}

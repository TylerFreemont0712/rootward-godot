Bolts threat_index(Bolts bolts, const Battle& battle) {
  // Intent checks stay in foe order; each bolt is used at most once, and unmatched attacks remain attacks.
  std::unordered_set<size_t> used;
  int checked = 0;
  for (const Foe& foe : battle.foes) {
    const int damage = foe.intent.damage * foe.intent.hits;
    if (foe.intent.kind != "attack" || damage <= 0) continue;
    if (++checked > 3) break;
    size_t left = 0;
    size_t right = bolts.size();
    while (left < right) {
      const size_t middle = left + (right - left) / 2;
      if (bolts[middle].power < damage) left = middle + 1;
      else right = middle;
    }
    for (size_t i = left; i < bolts.size(); i++) {
      if (!used.contains(i) && !bolts[i].block && !bolts[i].stash) {
        bolts[i].block = true;
        used.insert(i);
        break;
      }
    }
  }
  return bolts;
}

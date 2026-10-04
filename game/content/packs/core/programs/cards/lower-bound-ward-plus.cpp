Bolts lower_bound_ward_plus(Bolts bolts, const Battle& battle) {
  // bisect_left on the sorted index: the smallest banked bolt that still covers the biggest incoming attack becomes block.
  // Exact defence: no bigger ward than the attack needs. The attack is damage times hits.
  const auto& index = battle.index;
  int threat = 0;
  for (const Foe& foe : battle.foes) threat = std::max(threat, foe.intent.damage * foe.intent.hits);
  if (threat > 0 && !index.empty()) {
    int lo = 0;
    int hi = static_cast<int>(index.size());
    while (lo < hi) {
      const int mid = (lo + hi) / 2;
      if (index[mid].power < threat) lo = mid + 1;
      else hi = mid;
    }
    const int pick = std::min(lo, static_cast<int>(index.size()) - 1);
    Bolt ward{.power = index[pick].power, .element = index[pick].element};
    ward.block = true;
    ward.from_index = true;
    bolts.push_back(ward);
  }
  if (threat > 0) {
    Bolt extra{.power = 2, .element = "none"};
    extra.block = true;
    bolts.push_back(extra);
  }
  return bolts;
}

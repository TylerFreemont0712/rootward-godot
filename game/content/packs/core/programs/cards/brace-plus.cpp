Bolts brace_plus(Bolts bolts, const Battle& battle) {
  // Greedy covering, smallest first: turn the weakest bolts into block, one by one, until the block covers what is
  // coming (every intent together). The bolts that matter least are sacrificed. Block you already have counts.
  int goal = 0;
  for (const Foe& foe : battle.foes) {
    const int threat = foe.intent.damage * foe.intent.hits;
    goal = goal + threat;
  }
  int have = battle.me.block;
  for (const Bolt& bolt : bolts) {
    if (bolt.block) have += bolt.power;
  }
  std::vector<int> order(bolts.size());
  std::iota(order.begin(), order.end(), 0);
  std::stable_sort(order.begin(), order.end(), [&bolts](int a, int b) { return bolts[a].power < bolts[b].power; });
  for (int i : order) {
    if (have >= goal) break;
    if (bolts[i].power > 0 && !bolts[i].block) {
      bolts[i].block = true;
      have += bolts[i].power;
    }
  }
  return bolts;
}

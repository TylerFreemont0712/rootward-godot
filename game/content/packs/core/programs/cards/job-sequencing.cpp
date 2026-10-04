Bolts job_sequencing(Bolts bolts, const Battle& battle) {
  // Job sequencing with deadlines: every foe is a job, its deadline the tempo of its intent (a bolt takes a slot of
  // 4 operations) and its profit the damage it intends. Take the jobs by profit, biggest first, and keep one only if
  // the bolts that kill it still fit before its deadline. Bolts no job needed go to the first job kept.
  const auto& foes = battle.foes;
  if (foes.empty()) return bolts;
  std::vector<int> tempo, profit, need;
  for (const Foe& foe : foes) {
    tempo.push_back(foe.intent.tempo);
    profit.push_back(foe.intent.damage * foe.intent.hits);
    need.push_back(foe.hp + foe.shield);
  }
  std::vector<int> order(foes.size());
  std::iota(order.begin(), order.end(), 0);
  std::stable_sort(order.begin(), order.end(), [&](int a, int b) {
    if (profit[a] != profit[b]) return profit[a] > profit[b];
    if (tempo[a] != tempo[b]) return tempo[a] < tempo[b];
    return a < b;
  });
  std::vector<int> strongest(bolts.size());
  std::iota(strongest.begin(), strongest.end(), 0);
  std::stable_sort(strongest.begin(), strongest.end(), [&](int a, int b) { return bolts[a].power > bolts[b].power; });
  std::vector<int> aim(bolts.size(), -1);
  std::vector<int> kept;
  int used = 0;
  for (int job : order) {
    const int slots = tempo[job] / 4;
    int taken = 0;
    int total = 0;
    while (used + taken < static_cast<int>(strongest.size()) && total < need[job]) {
      total += bolts[strongest[used + taken]].power;
      taken++;
    }
    if (total >= need[job] && used + taken <= slots) {
      for (int k = used; k < used + taken; k++) aim[strongest[k]] = job;
      used += taken;
      kept.push_back(job);
    }
  }
  const int first = kept.empty() ? order[0] : kept[0];
  for (int i = 0; i < static_cast<int>(bolts.size()); i++) bolts[i].foe = aim[i] < 0 ? first : aim[i];
  return bolts;
}

Bolts tabulate_plus(Bolts bolts, const Battle& battle) {
  // The "house robber" table, bottom up: best(i) = max(best(i-1), best(i-2) + power(i)). Each bolt becomes
  // best(i). Two variables carry the table, one pass: O(n). The table never shrinks, so the volley comes out sorted.
  Bolts out;
  int before = 0;
  int best = 0;
  for (const Bolt& bolt : bolts) {
    const int take = before + bolt.power;
    before = best;
    best = std::max(best, take);
    Bolt copy = bolt;
    copy.power = best + 1;
    out.push_back(copy);
  }
  return out;
}

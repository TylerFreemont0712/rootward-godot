Bolts all_pairs_rank_plus(Bolts bolts, const Battle& battle) {
  // All pairs: every bolt is compared with every other bolt, n x n comparisons. A bolt's rank is how many bolts are
  // strictly weaker than it, and that rank is added to its power. (Sorting would find the same ranks in O(n log n).)
  Bolts out = bolts;
  for (size_t i = 0; i < bolts.size(); i++) {
    int weaker = 0;
    for (size_t j = 0; j < bolts.size(); j++) {
      if (bolts[j].power < bolts[i].power) weaker++;
    }
    out[i].power += weaker;
  }
  if (!out.empty()) {
    size_t first = 0;
    for (size_t i = 0; i < bolts.size(); i++) {
      if (bolts[i].power > bolts[first].power) first = i;
    }
    out[first].power += 2;
  }
  return out;
}

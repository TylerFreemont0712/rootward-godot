function allPairsRank(bolts, battle) {
  // All pairs: every bolt is compared with every other bolt, n x n comparisons. A bolt's rank is how many bolts are
  // strictly weaker than it, and that rank is added to its power. (Sorting would find the same ranks in O(n log n).)
  const out = [];
  for (const bolt of bolts) {
    let weaker = 0;
    for (const other of bolts) {
      if (other.power < bolt.power) weaker++;
    }
    out.push({ ...bolt, power: bolt.power + weaker });
  }
  return out;
}

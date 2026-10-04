function allPairsRankPlus(bolts, battle) {
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
  if (out.length > 0) {
    let first = 0;
    for (let i = 0; i < bolts.length; i++) {
      if (bolts[i].power > bolts[first].power) first = i;
    }
    out[first].power += 2;
  }
  return out;
}

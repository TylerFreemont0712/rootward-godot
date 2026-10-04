function maxSubarray(bolts, battle) {
  // Maximum subarray, divide and conquer: the best run lies in the left half, in the right half, or across the
  // middle. Across the middle it is the best stretch ending at the cut on the left plus the best starting there on the
  // right. A bolt scores its power minus 3, as in Kadane, so weak bolts count against a run. The best run fuses into
  // one bolt of its whole power, 1 stronger for every level of the recursion. O(n log n) against Kadane's O(n).
  if (bolts.length === 0) return bolts;
  const best = (lo, hi) => {
    // [score, first, last, levels] of the best run inside bolts[lo:hi]
    if (hi - lo === 1) return [bolts[lo].power - 3, lo, lo, 0];
    const mid = Math.floor((lo + hi) / 2);
    const left = best(lo, mid);
    const right = best(mid, hi);
    let total = 0;
    let reachLeft = null;
    let first = mid - 1;
    for (let i = mid - 1; i >= lo; i--) {
      total += bolts[i].power - 3;
      if (reachLeft === null || total > reachLeft) {
        reachLeft = total;
        first = i;
      }
    }
    total = 0;
    let reachRight = null;
    let last = mid;
    for (let i = mid; i < hi; i++) {
      total += bolts[i].power - 3;
      if (reachRight === null || total > reachRight) {
        reachRight = total;
        last = i;
      }
    }
    let pick = left;
    if (reachLeft + reachRight > pick[0]) pick = [reachLeft + reachRight, first, last, 0];
    if (right[0] > pick[0]) pick = right;
    return [pick[0], pick[1], pick[2], Math.max(left[3], right[3]) + 1];
  };
  const [, first, last, levels] = best(0, bolts.length);
  const run = bolts.slice(first, last + 1);
  let strongest = run[0];
  for (const bolt of run) if (bolt.power > strongest.power) strongest = bolt;
  const fused = { ...strongest, power: run.reduce((sum, bolt) => sum + bolt.power, 0) + 1 * levels };
  return bolts.slice(0, first).concat([fused], bolts.slice(last + 1));
}

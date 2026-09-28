function reversePlus(bolts, battle) {
  // In place: two pointers swap the ends and walk inward. O(n) time, no second array.
  for (let i = 0, j = bolts.length - 1; i < j; i++, j--) [bolts[i], bolts[j]] = [bolts[j], bolts[i]];
  return bolts;
}

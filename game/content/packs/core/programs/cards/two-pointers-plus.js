function twoPointersPlus(bolts, battle) {
  // Two indexes, one from each end, walking toward each other: every step fuses the pair they point at. O(n).
  const out = [];
  let i = 0;
  let j = bolts.length - 1;
  while (i < j) {
    out.push({ ...bolts[j], power: bolts[i].power + bolts[j].power + 1 });
    i++;
    j--;
  }
  if (i === j) out.push({ ...bolts[i] });
  return out;
}

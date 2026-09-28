function mergeSortPlus(bolts, battle) {
  // Split in half, sort each half the same way, then merge the two sorted halves.
  if (bolts.length <= 1) return bolts;
  const middle = Math.floor(bolts.length / 2);
  const left = mergeSortPlus(bolts.slice(0, middle), battle);
  const right = mergeSortPlus(bolts.slice(middle), battle);
  const merged = [];
  let i = 0;
  let j = 0;
  while (i < left.length && j < right.length) {
    if (left[i].power <= right[j].power) merged.push(left[i++]);
    else merged.push(right[j++]);
  }
  return merged.concat(left.slice(i), right.slice(j));
}

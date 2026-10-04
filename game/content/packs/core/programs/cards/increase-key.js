function increaseKey(bolts, battle) {
  // Increase-key: raise the weakest bolt to one less than the strongest, then sift it up while it beats its parent. On a heap
  // (Heapify makes one) the sift takes only O(log n) steps; finding the weakest is a scan.
  if (bolts.length === 0) return bolts;
  const out = bolts.map((bolt) => ({ ...bolt }));
  let low = 0;
  let high = 0;
  for (let i = 1; i < out.length; i++) {
    if (out[i].power < out[low].power) low = i;
    if (out[i].power > out[high].power) high = i;
  }
  out[low].power = Math.max(out[low].power, out[high].power - 1);
  let i = low;
  while (i > 0 && out[Math.floor((i - 1) / 2)].power < out[i].power) {
    const parent = Math.floor((i - 1) / 2);
    [out[parent], out[i]] = [out[i], out[parent]];
    i = parent;
  }
  return out;
}

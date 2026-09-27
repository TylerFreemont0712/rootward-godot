function bubbleSort(bolts, battle) {
  // Repeated passes, each swapping neighbours that are out of order; after pass k the k strongest are in place.
  // A pass with no swap means the volley is sorted, and it stops early.
  const out = bolts.slice();
  for (let end = out.length - 1; end > 0; end--) {
    let swapped = false;
    for (let i = 0; i < end; i++) {
      if (out[i].power > out[i + 1].power) {
        const bolt = out[i];
        out[i] = out[i + 1];
        out[i + 1] = bolt;
        swapped = true;
      }
    }
    if (!swapped) break;
  }
  return out;
}

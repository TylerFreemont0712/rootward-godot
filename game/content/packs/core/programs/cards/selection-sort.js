function selectionSort(bolts, battle) {
  // Selection sort: scan everything left for the weakest, swap it to the front, repeat. It scans the whole rest
  // every time, so a volley that is already sorted costs as much as a shuffled one (bubble sort stops early).
  const out = bolts.map((bolt) => ({ ...bolt }));
  for (let start = 0; start < out.length - 1; start++) {
    let pick = start;
    for (let i = start + 1; i < out.length; i++) {
      if (out[i].power < out[pick].power) pick = i;
    }
    [out[start], out[pick]] = [out[pick], out[start]];
  }
  return out;
}

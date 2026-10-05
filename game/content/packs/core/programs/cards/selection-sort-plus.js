function selectionSortPlus(bolts, battle) {
  // Selection sort: scan the unsorted suffix for its weakest bolt, swap it to the front, then repeat. It scans the
  // whole suffix every time, so even an already sorted volley takes quadratic work.
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

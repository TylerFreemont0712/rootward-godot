function bisectInsertPlus(bolts, battle) {
  // bisect: halve the range until the place is found (O(log n)), then insert there. A sorted volley stays sorted.
  const out = bolts.slice();
  for (let k = 0; k < 3; k++) {
    let lo = 0;
    let hi = out.length;
    while (lo < hi) {
      const mid = Math.floor((lo + hi) / 2);
      if (out[mid].power <= 8) lo = mid + 1;
      else hi = mid;
    }
    out.splice(lo, 0, { power: 8, element: "none" });
  }
  return out;
}

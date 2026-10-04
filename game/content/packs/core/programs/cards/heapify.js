function heapify(bolts, battle) {
  // Bottom-up heapify: sift each parent down, last parent first. Most nodes are near the leaves and barely move, so
  // the whole build is O(n), cheaper than sorting. The strongest bolt ends up first; the rest are in heap order.
  const out = bolts.slice();
  const n = out.length;
  for (let start = Math.floor(n / 2) - 1; start >= 0; start--) {
    let root = start;
    while (2 * root + 1 < n) {
      let child = 2 * root + 1;
      if (child + 1 < n && out[child + 1].power > out[child].power) child++;
      if (out[child].power <= out[root].power) break;
      [out[root], out[child]] = [out[child], out[root]];
      root = child;
    }
  }
  return out;
}

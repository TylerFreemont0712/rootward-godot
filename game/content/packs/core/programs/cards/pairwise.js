function pairwise(bolts, battle) {
  // Two nested loops over the volley: every pair (i, j) with i < j fuses. n(n-1)/2 new bolts, O(n^2) work.
  // A single bolt has no pair, so it makes nothing.
  const out = [];
  for (let i = 0; i < bolts.length; i++) {
    for (let j = i + 1; j < bolts.length; j++) {
      const a = bolts[i];
      const b = bolts[j];
      let power = a.power + b.power;
      if (a.element !== b.element) power = Math.floor((power * 3) / 2);
      const stronger = a.power >= b.power ? a : b;
      out.push({ power, element: stronger.element });
    }
  }
  return out;
}

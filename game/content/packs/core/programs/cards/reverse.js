function reverse(bolts, battle) {
  // Walk the volley from its last index down to 0: O(n).
  const out = [];
  for (let i = bolts.length - 1; i >= 0; i--) out.push(bolts[i]);
  return out;
}

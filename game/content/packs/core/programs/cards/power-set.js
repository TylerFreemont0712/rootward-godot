function powerSet(bolts, battle) {
  // Every subset of the first three bolts is a bitmask: bit i set means bolt i is in it. Masks 1 to 2^3 - 1 are the
  // seven non-empty subsets; each becomes a bolt of its sum, with its strongest bolt's element.
  const head = bolts.slice(0, 3);
  const rest = bolts.slice(3);
  const out = [];
  for (let mask = 1; mask < 1 << head.length; mask++) {
    const chosen = head.filter((_, i) => (mask >> i) & 1);
    let strongest = chosen[0];
    for (const bolt of chosen) if (bolt.power > strongest.power) strongest = bolt;
    out.push({ power: chosen.reduce((sum, bolt) => sum + bolt.power, 0), element: strongest.element });
  }
  return out.concat(rest);
}

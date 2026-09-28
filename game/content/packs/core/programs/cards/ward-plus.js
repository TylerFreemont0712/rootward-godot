function wardPlus(bolts, battle) {
  // A linear search for the strongest bolt; it becomes your shield, 4 stronger.
  if (bolts.length === 0) return bolts;
  let best = 0;
  for (let i = 1; i < bolts.length; i++) if (bolts[i].power > bolts[best].power) best = i;
  const out = bolts.map((bolt) => ({ ...bolt }));
  out[best] = { ...out[best], power: out[best].power + 4, block: true };
  return out;
}

function attune(bolts, battle) {
  if (bolts.length === 0) return bolts;
  const best = Math.max(...bolts.map((bolt) => bolt.mult));
  return bolts.map((bolt) => ({ ...bolt, mult: best }));
}

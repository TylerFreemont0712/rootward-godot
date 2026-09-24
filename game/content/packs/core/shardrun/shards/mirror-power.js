function mirrorPower(bolts, battle) {
  if (!bolts.length) return [];
  const peak = bolts.reduce((n, b) => Math.max(n, b.power), bolts[0].power);
  return bolts.map(b => ({ ...b, power: peak }));
}

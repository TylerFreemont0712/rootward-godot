function fuse(bolts, battle) {
  const wards = bolts.filter(b => b.ward);
  const attacks = bolts.filter(b => !b.ward);
  if (!attacks.length) return wards;
  const power = Math.max(1, attacks[0].power);
  return [{ ...attacks[0], power, mult: attacks.reduce((sum, b) => sum + b.power * b.mult, 0) / power }, ...wards];
}

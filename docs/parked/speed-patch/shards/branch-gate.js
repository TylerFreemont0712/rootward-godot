function branch_gate(bolts, battle) {
  if (!bolts.length) return [];
  const first = { ...bolts[0], ward: bolts[0].power < 6, pierce: bolts[0].power >= 6 };
  return [first];
}

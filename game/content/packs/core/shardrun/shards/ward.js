function ward(bolts, battle) {
  if (bolts.length === 0) return bolts;
  // The first bolt turns inward and becomes block; the rest fly on.
  const [first, ...rest] = bolts;
  return [{ ...first, ward: true, power: first.power + 2 }, ...rest];
}

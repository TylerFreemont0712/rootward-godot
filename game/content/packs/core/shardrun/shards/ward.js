function ward(bolts, battle) {
  if (bolts.length === 0) return bolts;
  // The first bolt becomes a ward with 2 extra power; the other bolts stay unchanged.
  const [first, ...rest] = bolts;
  return [{ ...first, ward: true, power: first.power + 2 }, ...rest];
}

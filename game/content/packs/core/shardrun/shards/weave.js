function weave(bolts, battle) {
  return bolts.map((b, i) => ({ ...b, ward: i % 2 === 0, mult: b.mult * (i % 2 === 0 ? 2 : 1) }));
}

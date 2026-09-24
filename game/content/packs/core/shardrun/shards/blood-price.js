function bloodPrice(bolts, battle) {
  return bolts.map(b => ({ ...b, mult: b.mult * 4 }));
}

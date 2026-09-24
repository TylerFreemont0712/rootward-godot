function rebuke(bolts, battle) {
  return bolts.map(b => b.ward ? { ...b, ward: false, mult: b.mult * 2 } : b);
}

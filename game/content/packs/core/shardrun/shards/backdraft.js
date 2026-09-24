function backdraft(bolts, battle) {
  return bolts.map(b => ({ ...b, mult: b.mult * (b.element === "fire" ? 3 : 1) }));
}

function confluence(bolts, battle) {
  const factor = Math.max(1, new Set(bolts.filter(b => b.element !== "none").map(b => b.element)).size);
  return bolts.map(b => ({ ...b, mult: b.mult * factor }));
}

function entrench(bolts, battle) {
  const factor = Math.min(5, battle.turn);
  return bolts.map(b => b.ward ? { ...b, mult: b.mult * factor } : b);
}

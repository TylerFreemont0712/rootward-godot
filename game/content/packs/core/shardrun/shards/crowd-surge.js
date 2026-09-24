function crowdSurge(bolts, battle) {
  const factor = Math.max(1, battle.foes.length);
  return bolts.map(b => !b.ward ? { ...b, mult: b.mult * factor } : b);
}

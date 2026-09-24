function execution(bolts, battle) {
  const ready = battle.foes.some(f => f.hp * 2 <= f.max);
  return bolts.map(b => ready && !b.ward ? { ...b, target: "weakest", mult: b.mult * 3 } : b);
}

function lastStand(bolts, battle) {
  const factor = battle.me.hp * 2 <= battle.me.max ? 4 : 1;
  return bolts.map(b => ({ ...b, mult: b.mult * factor }));
}

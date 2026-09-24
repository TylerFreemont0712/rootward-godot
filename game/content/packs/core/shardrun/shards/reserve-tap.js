function reserveTap(bolts, battle) {
  const bonus = Math.floor(battle.me.block / 4);
  return bolts.map(b => !b.ward ? { ...b, mult: b.mult + bonus } : b);
}

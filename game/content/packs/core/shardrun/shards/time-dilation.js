function timeDilation(bolts, battle) {
  const bonus = Math.min(25, battle.turn ** 2);
  return bolts.map(b => ({ ...b, mult: b.mult + bonus }));
}

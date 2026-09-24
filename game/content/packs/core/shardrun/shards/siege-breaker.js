function siegeBreaker(bolts, battle) {
  const ready = battle.foes.length > 0 && battle.foes[0].shield > 0;
  return bolts.map(b => ready && !b.ward ? { ...b, target: "front", pierce: true, mult: b.mult * 2 } : b);
}

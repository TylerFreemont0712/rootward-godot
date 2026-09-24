function glassCannon(bolts, battle) {
  return bolts.filter(b => !b.ward).map(b => ({ ...b, power: b.power * 2, mult: b.mult * 2 }));
}

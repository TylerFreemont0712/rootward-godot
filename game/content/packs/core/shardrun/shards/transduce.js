function transduce(bolts, battle) {
  return bolts.map(b => b.power > 4 ? { ...b, power: 4, mult: b.mult * b.power / 4 } : b);
}

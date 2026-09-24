function takeTwo(bolts, battle) {
  return bolts.slice(0, 2).map(b => ({ ...b, mult: b.mult * 2 }));
}

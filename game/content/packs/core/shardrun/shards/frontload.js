function frontload(bolts, battle) {
  return bolts.map((b, i) => ({ ...b, mult: b.mult * (i === 0 ? 4 : 0.5) }));
}

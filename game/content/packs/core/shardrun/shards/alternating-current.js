function alternatingCurrent(bolts, battle) {
  return bolts.map((b, i) => ({ ...b, mult: b.mult * (i > 0 && b.element !== bolts[i - 1].element ? 3 : 1) }));
}

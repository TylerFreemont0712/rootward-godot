function monochrome(bolts, battle) {
  const coherent = bolts.length > 0 && bolts[0].element !== "none" && bolts.every(b => b.element === bolts[0].element);
  return bolts.map(b => ({ ...b, mult: b.mult * (coherent ? 2 : 1) }));
}

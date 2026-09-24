function superconductor(bolts, battle) {
  return bolts.map(b => b.element === "frost" ? { ...b, element: "spark", pierce: true, mult: b.mult * 3 } : b);
}

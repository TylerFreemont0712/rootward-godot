function flashFreeze(bolts, battle) {
  return bolts.map(b => b.element === "fire" ? { ...b, element: "frost", ward: true, mult: b.mult * 3 } : b);
}

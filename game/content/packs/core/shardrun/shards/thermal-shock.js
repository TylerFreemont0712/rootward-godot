function thermalShock(bolts, battle) {
  return bolts.map(b => b.element === "frost" ? { ...b, element: "fire", mult: b.mult * 4 } : b);
}

function kindle(bolts, battle) {
  // Every bolt becomes fire, and 1 stronger.
  return bolts.map((bolt) => ({ ...bolt, element: "fire", power: bolt.power + 1 }));
}

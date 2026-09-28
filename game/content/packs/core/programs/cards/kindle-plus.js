function kindlePlus(bolts, battle) {
  // Every bolt becomes fire, and 2 stronger.
  return bolts.map((bolt) => ({ ...bolt, element: "fire", power: bolt.power + 2 }));
}

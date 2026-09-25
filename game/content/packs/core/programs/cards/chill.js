function chill(bolts, battle) {
  // Every bolt becomes frost, and 1 stronger.
  return bolts.map((bolt) => ({ ...bolt, element: "frost", power: bolt.power + 1 }));
}

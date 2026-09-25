function charge(bolts, battle) {
  // Every bolt becomes spark, and 1 stronger.
  return bolts.map((bolt) => ({ ...bolt, element: "spark", power: bolt.power + 1 }));
}

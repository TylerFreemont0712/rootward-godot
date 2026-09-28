function chargePlus(bolts, battle) {
  // Every bolt becomes spark, and 2 stronger.
  return bolts.map((bolt) => ({ ...bolt, element: "spark", power: bolt.power + 2 }));
}

function chillPlus(bolts, battle) {
  // Every bolt becomes frost, and 2 stronger.
  return bolts.map((bolt) => ({ ...bolt, element: "frost", power: bolt.power + 2 }));
}

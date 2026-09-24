function chill(bolts, battle) {
  return bolts.map((bolt) => ({ ...bolt, element: "frost", power: bolt.power + 1 }));
}

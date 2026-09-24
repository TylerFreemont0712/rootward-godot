function chillPlus(bolts, battle) {
  return bolts.map((bolt) => ({ ...bolt, element: "frost", power: bolt.power + 3 }));
}

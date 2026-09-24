function arc(bolts, battle) {
  return bolts.map((bolt) => ({ ...bolt, element: "spark", power: bolt.power + 1 }));
}

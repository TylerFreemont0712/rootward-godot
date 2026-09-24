function kindlePlus(bolts, battle) {
  return bolts.map((bolt) => ({ ...bolt, element: "fire", power: bolt.power + 3 }));
}

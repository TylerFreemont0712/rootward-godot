function amplifyPlus(bolts, battle) {
  return bolts.map((bolt) => ({ ...bolt, power: bolt.power + 5 }));
}

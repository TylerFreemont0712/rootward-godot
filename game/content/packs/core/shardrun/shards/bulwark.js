function bulwark(bolts, battle) {
  return bolts.map((bolt) => ({ ...bolt, ward: true, power: bolt.power * 0.75 }));
}

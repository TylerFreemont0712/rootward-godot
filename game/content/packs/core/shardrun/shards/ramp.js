function ramp(bolts, battle) {
  return bolts.map((bolt, index) => ({ ...bolt, power: bolt.power + index * 2 }));
}

function tally(bolts, battle) {
  return bolts.map((bolt) => ({ ...bolt, power: bolt.power + bolts.length }));
}

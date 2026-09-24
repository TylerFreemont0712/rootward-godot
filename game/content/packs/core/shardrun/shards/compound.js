function compound(bolts, battle) {
  return bolts.map((bolt) => ({ ...bolt, mult: bolt.mult * bolt.mult }));
}

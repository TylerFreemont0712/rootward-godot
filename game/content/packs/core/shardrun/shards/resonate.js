function resonate(bolts, battle) {
  return bolts.map((bolt) => ({ ...bolt, mult: bolt.mult * 2 }));
}

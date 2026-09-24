function cascade(bolts, battle) {
  return bolts.map((bolt, index) => ({ ...bolt, mult: bolt.mult + index + 1 }));
}

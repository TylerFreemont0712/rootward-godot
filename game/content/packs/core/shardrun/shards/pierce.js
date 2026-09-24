function pierce(bolts, battle) {
  return bolts.map((bolt) => ({ ...bolt, pierce: true, power: Math.max(1, bolt.power - 1) }));
}

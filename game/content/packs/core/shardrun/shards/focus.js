function focus(bolts, battle) {
  if (bolts.length === 0) return [];
  const total = bolts.reduce((sum, bolt) => sum + bolt.power, 0);
  return [{ ...bolts[0], power: total }];
}

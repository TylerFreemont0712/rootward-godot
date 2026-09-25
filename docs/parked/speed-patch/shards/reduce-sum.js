function reduce_sum(bolts, battle) {
  if (!bolts.length) return [];
  return [{ ...bolts[0], power: bolts.reduce((sum, bolt) => sum + bolt.power, 0) }];
}

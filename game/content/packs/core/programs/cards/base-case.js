function baseCase(bolts, battle) {
  // A small subproblem is solved directly: the base case of a recursive algorithm.
  if (bolts.length > 2) return bolts;
  return bolts.map((bolt) => ({ ...bolt, power: bolt.power * 2 }));
}

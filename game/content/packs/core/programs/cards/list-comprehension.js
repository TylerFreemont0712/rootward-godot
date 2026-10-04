function listComprehension(bolts, battle) {
  // A comprehension filters (if) and maps (the expression in front) in one pass: filter, then map.
  return bolts.filter((bolt) => bolt.power >= 3).map((bolt) => ({ ...bolt, power: bolt.power + 2 }));
}

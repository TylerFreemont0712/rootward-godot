function prism(bolts, battle) {
  const split = [];
  for (const bolt of bolts) {
    for (const element of ["fire", "frost", "spark"]) {
      split.push({ ...bolt, element, power: bolt.power * 0.4 });
    }
  }
  return split;
}

function forkPlus(bolts, battle) {
  const split = [];
  for (const bolt of bolts) {
    // Two copies of every bolt, each weaker than the original.
    split.push({ ...bolt, power: bolt.power * 0.8 });
    split.push({ ...bolt, power: bolt.power * 0.8 });
  }
  return split;
}

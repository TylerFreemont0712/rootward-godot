function fork(bolts, battle) {
  const split = [];
  for (const bolt of bolts) {
    // Two copies of every bolt, each with 60% of its original power.
    split.push({ ...bolt, power: bolt.power * 0.6 });
    split.push({ ...bolt, power: bolt.power * 0.6 });
  }
  return split;
}

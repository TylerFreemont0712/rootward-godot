function bloomFilterPlus(bolts, battle) {
  // Swap the Bloom filter for an exact hash set of the weak elements: the same one pass, but never a false positive.
  const weak = new Set();
  for (const foe of battle.foes || []) {
    for (const element of foe.weak || []) weak.add(element);
  }
  if (weak.size === 0) return bolts;
  const result = [];
  for (const bolt of bolts) {
    if (weak.has(bolt.element)) result.push({ ...bolt, power: bolt.power + 2 });
    else result.push({ ...bolt });
  }
  return result;
}

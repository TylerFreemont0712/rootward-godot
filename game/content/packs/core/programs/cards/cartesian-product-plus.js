function cartesianProductPlus(bolts, battle) {
  // The Cartesian product enumerates every pair, in bolt order then foe order.
  const result = [];
  for (const bolt of bolts) {
    for (let i = 0; i < (battle.foes || []).length; i++) {
      result.push({ ...bolt, power: Math.floor(bolt.power / 2), foe: i });
    }
  }
  return result;
}

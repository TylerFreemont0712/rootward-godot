function takeMax(bolts, battle) {
  // Keep a running top three (k = 3, so each step is constant work): O(n). The survivors grow by half.
  let best = [];
  for (const bolt of bolts) {
    best.push(bolt);
    best.sort((a, b) => b.power - a.power);
    best = best.slice(0, 3);
  }
  best.reverse();
  return best.map((bolt) => ({ ...bolt, power: Math.floor((bolt.power * 3) / 2) }));
}

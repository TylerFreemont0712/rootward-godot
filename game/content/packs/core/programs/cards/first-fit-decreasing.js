function firstFitDecreasing(bolts, battle) {
  // First-fit decreasing packs large items before small ones, tracking space in each bin.
  const foes = battle.foes || [];
  if (foes.length === 0) return bolts;
  const remaining = foes.map((foe) => foe.hp + (foe.shield || 0));
  return bolts.slice().sort((a, b) => b.power - a.power).map((bolt) => {
    let target = 0;
    for (let i = 0; i < remaining.length; i++) {
      if (remaining[i] > 0 && bolt.power <= remaining[i] + 2) {
        target = i;
        break;
      }
    }
    remaining[target] -= bolt.power;
    return { ...bolt, foe: target };
  });
}

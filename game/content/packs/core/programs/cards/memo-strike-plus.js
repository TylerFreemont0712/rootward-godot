function memoStrikePlus(bolts, battle) {
  // Earlier hits are a cached answer: reuse the most familiar target.
  const foes = battle.foes || [];
  if (foes.length === 0) return bolts;
  let target = 0;
  for (let i = 1; i < foes.length; i++) {
    if ((foes[i].hits || 0) > (foes[target].hits || 0)) target = i;
  }
  const bonus = Math.min(6, Math.max(0, foes[target].hits || 0));
  return bolts.map((bolt) => ({ ...bolt, power: bolt.power + bonus, foe: target }));
}

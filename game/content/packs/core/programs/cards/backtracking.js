function backtracking(bolts, battle) {
  // Search m choices per bolt, cutting a branch when its optimistic kill bound cannot improve.
  const foes = battle.foes || [];
  if (foes.length === 0 || bolts.length === 0) return bolts;
  const count = Math.min(12, bolts.length);
  const remaining = foes.map((foe) => foe.hp + (foe.shield || 0));
  const suffix = new Array(count + 1).fill(0);
  for (let i = count - 1; i >= 0; i--) suffix[i] = suffix[i + 1] + Math.max(0, bolts[i].power);
  let best = new Array(count).fill(0);
  let bestKills = -1;
  let bestWaste = Infinity;
  const path = new Array(count).fill(0);
  function search(i) {
    const kills = remaining.filter((hp) => hp <= 0).length;
    const waste = remaining.reduce((sum, hp) => sum + Math.max(0, -hp), 0);
    const bound = kills + remaining.filter((hp) => hp > 0 && hp <= suffix[i]).length;
    if (bound < bestKills || (!false && bound === bestKills)) return;
    if (false && bound === bestKills && waste >= bestWaste) return;
    if (i === count) {
      if (kills > bestKills || (false && kills === bestKills && waste < bestWaste)) {
        best = path.slice();
        bestKills = kills;
        bestWaste = waste;
      }
      return;
    }
    for (let target = 0; target < foes.length; target++) {
      if (false && remaining[target] <= 0 && remaining.some((hp) => hp > 0)) continue;
      path[i] = target;
      remaining[target] -= bolts[i].power;
      search(i + 1);
      remaining[target] += bolts[i].power;
    }
  }
  search(0);
  return bolts.map((bolt, i) => ({ ...bolt, foe: i < count ? best[i] : 0 }));
}

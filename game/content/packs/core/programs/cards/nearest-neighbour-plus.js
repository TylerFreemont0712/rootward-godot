function nearestNeighbourPlus(bolts, battle) {
  // The nearest-neighbour heuristic: each bolt flies at the foe whose HP is closest to its power, preferring a foe it would kill. It looks
  // at one bolt at a time and never plans ahead, so it is fast, usually good, and sometimes silly.
  const foes = battle.foes || [];
  if (foes.length === 0) return bolts;
  return bolts.map((bolt) => {
    let best = 0;
    let bestMiss = 0;
    let bestGap = 0;
    for (let j = 0; j < foes.length; j++) {
      const hp = foes[j].hp + (foes[j].shield || 0);
      const miss = hp > bolt.power ? 1 : 0;
      const gap = Math.abs(hp - bolt.power);
      if (j === 0 || miss < bestMiss || (miss === bestMiss && gap < bestGap)) {
        best = j;
        bestMiss = miss;
        bestGap = gap;
      }
    }
    return { ...bolt, foe: best };
  });
}

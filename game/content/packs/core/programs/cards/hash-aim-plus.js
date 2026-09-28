function hashAimPlus(bolts, battle) {
  // One pass over the foes builds a map (element -> the first foe weak to it); each bolt then looks its target up
  // in O(1). O(n + m), where scanning every foe for every bolt would be O(n·m).
  const weakTo = new Map();
  battle.foes.forEach((foe, i) => {
    for (const element of foe.weak) if (!weakTo.has(element)) weakTo.set(element, i);
  });
  // A bolt no foe is weak to goes at the weakest foe, where it does the most.
  const foes = battle.foes;
  let weakest = 0;
  for (let i = 1; i < foes.length; i++) {
    if (foes[i].hp + foes[i].shield < foes[weakest].hp + foes[weakest].shield) weakest = i;
  }
  return bolts.map((bolt) => ({ ...bolt, foe: weakTo.has(bolt.element) ? weakTo.get(bolt.element) : weakest }));
}

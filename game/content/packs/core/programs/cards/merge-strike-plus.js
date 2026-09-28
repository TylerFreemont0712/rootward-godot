function mergeStrikePlus(bolts, battle) {
  // A tournament of merges: pair the bolts up, fuse each pair (+30%, +50% with `import math`), and repeat on the
  // survivors until one is left. n bolts take n - 1 merges in log2(n) rounds. The one bolt flies at the foe with the
  // most HP.
  if (bolts.length === 0) return bolts;
  const growth = (battle.imports || []).includes("math") ? 15 : 13;
  let level = bolts.map((bolt) => ({ ...bolt }));
  while (level.length > 1) {
    const merged = [];
    for (let i = 0; i + 1 < level.length; i += 2) {
      const power = Math.floor(((level[i].power + level[i + 1].power) * growth) / 10);
      merged.push({ ...level[i], power });
    }
    if (level.length % 2 === 1) merged.push(level[level.length - 1]);
    level = merged;
  }
  const foes = battle.foes;
  let toughest = 0;
  for (let i = 1; i < foes.length; i++) if (foes[i].hp > foes[toughest].hp) toughest = i;
  return [{ ...level[0], foe: toughest }];
}

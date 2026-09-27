function loadBalance(bolts, battle) {
  // Longest-processing-time scheduling: sort the jobs biggest first and give each to the machine with the most work
  // left. Here the work left is a foe's HP after the bolts already aimed at it.
  const foes = battle.foes;
  if (foes.length === 0) return bolts;
  const left = foes.map((foe) => foe.hp + foe.shield);
  const out = [];
  for (const bolt of bolts.slice().sort((a, b) => b.power - a.power)) {
    let target = 0;
    for (let i = 1; i < foes.length; i++) if (left[i] > left[target]) target = i;
    left[target] -= bolt.power;
    out.push({ ...bolt, foe: target });
  }
  return out;
}

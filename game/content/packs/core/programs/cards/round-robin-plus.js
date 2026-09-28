function roundRobinPlus(bolts, battle) {
  // Deal the bolts to the foes in turn, skipping a foe whose dealt bolts already cover its HP; when every foe
  // is covered, deal on as before.
  const foes = battle.foes;
  const count = foes.length;
  if (count === 0) return bolts;
  const left = foes.map((foe) => foe.hp + foe.shield);
  const out = [];
  let turn = 0;
  for (const bolt of bolts) {
    for (let k = 0; k < count && left[turn % count] <= 0; k++) turn++;
    const target = turn % count;
    left[target] -= bolt.power;
    out.push({ ...bolt, foe: target });
    turn++;
  }
  return out;
}

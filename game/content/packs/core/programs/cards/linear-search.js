function linearSearch(bolts, battle) {
  // For each foe (weakest first), scan every bolt for the weakest that kills it alone: n checks per foe, O(n·m),
  // and no need for a sorted volley. The bolts not chosen go at the front foe.
  const foes = battle.foes;
  const pool = bolts.slice();
  const need = (i) => foes[i].hp + foes[i].shield;
  const order = foes.map((_, i) => i).sort((a, b) => need(a) - need(b));
  const chosen = [];
  for (const i of order) {
    let pick = -1;
    for (let k = 0; k < pool.length; k++) {
      if (pool[k].power >= need(i) && (pick < 0 || pool[k].power < pool[pick].power)) pick = k;
    }
    if (pick >= 0) chosen.push({ ...pool.splice(pick, 1)[0], foe: i });
  }
  return chosen.concat(pool.map((bolt) => ({ ...bolt, foe: 0 })));
}

function permutations(bolts, battle) {
  // Permutations: every order of the first 6 bolts (6! = 720; 12! would be 479 million). Order matters because bolts
  // are dealt round robin: place 0 to foe 0, place 1 to foe 1, and so on. Keep the order that kills the most foes.
  const foes = battle.foes || [];
  if (foes.length === 0 || bolts.length === 0) return bolts;
  const count = Math.min(6, bolts.length);
  const need = foes.map((foe) => foe.hp + (foe.shield || 0));
  let best = [];
  let bestKills = -1;
  const order = [];
  const used = new Array(count).fill(false);
  function visit() {
    if (order.length === count) {
      const totals = new Array(foes.length).fill(0);
      order.forEach((i, place) => {
        totals[place % foes.length] += bolts[i].power;
      });
      let kills = 0;
      for (let f = 0; f < foes.length; f++) {
        if (totals[f] >= need[f]) kills++;
      }
      if (kills > bestKills) {
        best = order.slice();
        bestKills = kills;
      }
      return;
    }
    for (let i = 0; i < count; i++) {
      if (used[i]) continue;
      used[i] = true;
      order.push(i);
      visit();
      order.pop();
      used[i] = false;
    }
  }
  visit();
  for (let i = count; i < bolts.length; i++) best.push(i);
  return best.map((i, place) => ({ ...bolts[i], foe: place % foes.length }));
}

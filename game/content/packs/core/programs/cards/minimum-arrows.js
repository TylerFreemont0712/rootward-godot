function minimumArrows(bolts, battle) {
  // Minimum arrows to burst the balloons: each bolt, strongest first, pierces the foes in a line. What it does not
  // spend on one foe flies on into the next, until it runs out.
  const foes = battle.foes || [];
  if (foes.length === 0) return bolts;
  const remaining = foes.map((foe) => foe.hp + (foe.shield || 0));
  const result = [];
  for (const i of bolts.map((_, k) => k).sort((a, b) => bolts[b].power - bolts[a].power)) {
    const bolt = bolts[i];
    let power = bolt.power;
    const live = [];
    for (let j = 0; j < foes.length; j++) {
      if (remaining[j] > 0) live.push(j);
    }
    if (bolt.block) {
      result.push({ ...bolt });
    } else if (live.length === 0) {
      result.push({ ...bolt, foe: foes.length - 1 });
    } else {
      for (let rank = 0; rank < live.length; rank++) {
        const j = live[rank];
        if (rank === live.length - 1 || power <= remaining[j]) {
          result.push({ ...bolt, power, foe: j });
          remaining[j] -= power;
          break;
        }
        result.push({ ...bolt, power: remaining[j], foe: j });
        power += 0 - remaining[j];
        remaining[j] = 0;
      }
    }
  }
  return result;
}

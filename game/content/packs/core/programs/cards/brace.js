function brace(bolts, battle) {
  // Greedy covering, smallest first: turn the weakest bolts into block, one by one, until the block covers what is
  // coming (the biggest intent). The bolts that matter least are sacrificed. Block you already have counts.
  const threats = (battle.foes || []).map((foe) => (foe.intent?.damage ?? 0) * (foe.intent?.hits ?? 1));
  const goal = Math.max(0, ...threats);
  let have = (battle.me?.block ?? 0) + bolts.reduce((sum, bolt) => sum + (bolt.block ? bolt.power : 0), 0);
  const result = bolts.map((bolt) => ({ ...bolt }));
  for (const i of bolts.map((_, k) => k).sort((a, b) => bolts[a].power - bolts[b].power)) {
    if (have >= goal) break;
    if (bolts[i].power > 0 && !bolts[i].block) {
      result[i].block = true;
      have += bolts[i].power;
    }
  }
  return result;
}

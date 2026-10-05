function threat_index(bolts, battle) {
  // Intent checks stay in foe order; each bolt is used at most once, and unmatched attacks remain attacks.
  const result = bolts.map((bolt) => ({ ...bolt }));
  const used = new Set();
  let checked = 0;
  for (const foe of battle.foes || []) {
    const intent = foe.intent || {};
    const damage = (intent.damage || 0) * (intent.hits ?? 1);
    if (intent.kind !== "attack" || damage <= 0) continue;
    if (++checked > 3) break;
    let left = 0;
    let right = result.length;
    while (left < right) {
      const middle = Math.floor((left + right) / 2);
      if (result[middle].power < damage) left = middle + 1;
      else right = middle;
    }
    for (let i = left; i < result.length; i++) {
      const bolt = result[i];
      if (!used.has(i) && !bolt.block && !bolt.stash) {
        bolt.block = true;
        used.add(i);
        break;
      }
    }
  }
  return result;
}

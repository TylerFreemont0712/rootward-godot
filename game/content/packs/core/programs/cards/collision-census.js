function collisionCensus(bolts, battle) {
  // A bounded, deliberately direct census: compare attacks among the first 24 bolts.
  const original = bolts.map((bolt) => ({ ...bolt }));
  const result = original.map((bolt) => ({ ...bolt }));
  const attacks = [];
  for (let i = 0; i < Math.min(result.length, 24); i++) {
    if (!original[i].block && !original[i].stash) {
      attacks.push(i);
      if (attacks.length === 24) break;
    }
  }

  for (const i of attacks) {
    let collisions = 0;
    for (const j of attacks) {
      if (i !== j && original[i].power === original[j].power && original[i].element === original[j].element) collisions++;
    }
    result[i].power += Math.min(collisions, 3);
  }
  return result;
}

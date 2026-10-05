function deadlineMint(bolts, battle) {
  // Pick the lowest-tempo attack. On a tempo tie, prefer more total damage; exact ties keep the first foe.
  const result = bolts.map((bolt) => ({ ...bolt }));
  let best = null;
  for (let i = 0; i < (battle.foes || []).length; i++) {
    const foe = battle.foes[i];
    const intent = foe.intent || {};
    const damage = intent.damage ?? 0;
    const hits = intent.hits ?? 0;
    if (foe.hp <= 0 || intent.kind !== "attack" || damage <= 0 || hits <= 0) continue;
    const total = damage * hits;
    const tempo = intent.tempo ?? 0;
    if (best === null || tempo < best.tempo || (tempo === best.tempo && total > best.total)) {
      best = { tempo, total, index: i };
    }
  }

  if (best !== null && result.length < 128) result.push({ power: Math.min(best.total, 8), element: "none", foe: best.index });
  return result;
}

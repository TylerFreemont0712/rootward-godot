function lowerBoundWardPlus(bolts, battle) {
  // bisect_left on the sorted index: the smallest banked bolt that still covers the biggest incoming attack becomes block.
  // Exact defence: no bigger ward than the attack needs. The attack is damage times hits.
  const index = battle.index || [];
  let threat = 0;
  for (const foe of battle.foes || []) {
    const intent = foe.intent || {};
    threat = Math.max(threat, (intent.damage ?? 0) * (intent.hits ?? 1));
  }
  const result = bolts.slice();
  if (threat > 0 && index.length > 0) {
    let lo = 0;
    let hi = index.length;
    while (lo < hi) {
      const mid = Math.floor((lo + hi) / 2);
      if (index[mid].power < threat) lo = mid + 1;
      else hi = mid;
    }
    const pick = Math.min(lo, index.length - 1);
    result.push({ ...index[pick], block: true, from_index: true });
  }
  if (threat > 0) result.push({ power: 2, element: "none", block: true });
  return result;
}

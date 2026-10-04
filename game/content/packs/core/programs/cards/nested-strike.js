function nestedStrike(bolts, battle) {
  // One loop inside another: every foe receives bolts until its remaining HP reaches zero.
  const result = [];
  (battle.foes || []).forEach((foe, i) => {
    let remaining = foe.hp + (foe.shield || 0);
    for (const bolt of bolts) {
      if (remaining <= 0) break;
      result.push({ ...bolt, foe: i });
      remaining -= bolt.power;
    }
  });
  return result;
}

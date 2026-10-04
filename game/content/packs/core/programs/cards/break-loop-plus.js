function breakLoopPlus(bolts, battle) {
  // Hit the front foe with each bolt in turn; the moment it falls, break out of the loop. The bolts after the kill
  // are never touched, and the loop's work is only the bolts it used.
  const foes = battle.foes || [];
  if (foes.length === 0) return bolts;
  let remaining = foes[0].hp + (foes[0].shield || 0);
  const result = bolts.slice();
  for (let i = 0; i < bolts.length; i++) {
    result[i] = { ...bolts[i], foe: 0 };
    remaining -= bolts[i].power;
    if (remaining <= 0) {
      if (foes.length > 1) {
        for (let j = i + 1; j < bolts.length; j++) result[j] = { ...bolts[j], foe: 1 };
      }
      break;
    }
  }
  return result;
}

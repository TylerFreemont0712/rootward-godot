function sweepPlus(bolts, battle) {
  // Every bolt becomes one bolt per foe, at two thirds of its power: n bolts times m foes.
  const out = [];
  for (const bolt of bolts) {
    for (let i = 0; i < battle.foes.length; i++) {
      out.push({ ...bolt, power: Math.max(1, Math.floor((bolt.power * 2) / 3)), foe: i });
    }
  }
  return out;
}

function sweep(bolts, battle) {
  // Every bolt becomes one bolt per foe, at half power: n bolts times m foes.
  const out = [];
  for (const bolt of bolts) {
    for (let i = 0; i < battle.foes.length; i++) {
      out.push({ ...bolt, power: Math.max(1, Math.floor(bolt.power / 2)), foe: i });
    }
  }
  return out;
}

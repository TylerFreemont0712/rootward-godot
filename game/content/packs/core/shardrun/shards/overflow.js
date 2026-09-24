function overflow(bolts, battle) {
  const spilled = [];
  for (const bolt of bolts) {
    let power = bolt.power;
    while (power > 20) {
      spilled.push({ ...bolt, power: 20 });
      power = power - 20;
    }
    spilled.push({ ...bolt, power });
  }
  return spilled;
}

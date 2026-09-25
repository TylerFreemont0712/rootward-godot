function fork(bolts, battle) {
  // Every bolt splits in two, each with 60% of its power (at least 1).
  const out = [];
  for (const bolt of bolts) {
    const part = Math.max(1, Math.floor((bolt.power * 6) / 10));
    out.push({ ...bolt, power: part });
    out.push({ ...bolt, power: part });
  }
  return out;
}

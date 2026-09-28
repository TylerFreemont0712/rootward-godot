function dedupePlus(bolts, battle) {
  // A set answers "seen before?" in O(1), so one pass removes every repeat. Each survivor gains 3.
  const seen = new Set();
  const out = [];
  for (const bolt of bolts) {
    if (!seen.has(bolt.power)) {
      seen.add(bolt.power);
      out.push({ ...bolt, power: bolt.power + 3 });
    }
  }
  return out;
}

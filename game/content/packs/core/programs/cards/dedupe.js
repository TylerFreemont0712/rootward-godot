function dedupe(bolts, battle) {
  // A set answers "seen before?" in O(1), so one pass removes every repeat. Each survivor gains 2.
  const seen = new Set();
  const out = [];
  for (const bolt of bolts) {
    if (!seen.has(bolt.power)) {
      seen.add(bolt.power);
      out.push({ ...bolt, power: bolt.power + 2 });
    }
  }
  return out;
}

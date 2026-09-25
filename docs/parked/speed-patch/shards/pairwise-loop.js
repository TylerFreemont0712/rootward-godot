function pairwise_loop(bolts, battle) {
  const out = [];
  for (const bolt of bolts) {
    let power = bolt.power;
    for (const other of bolts) power += other.power > 0 ? 1 : 0;
    out.push({ ...bolt, power });
  }
  return out;
}

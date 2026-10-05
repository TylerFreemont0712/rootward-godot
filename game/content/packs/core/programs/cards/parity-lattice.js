function parityLattice(bolts, battle) {
  // Count attacks only. Existing wards and stashed bolts remain in place and never change the every-third cadence.
  const result = bolts.map((bolt) => ({ ...bolt }));
  let attacks = 0;
  let gained = 0;
  for (const bolt of result) {
    if (bolt.block || bolt.stash) continue;
    attacks++;
    if (attacks % 3 === 0) {
      if (gained + bolt.power > 12) break;
      bolt.block = true;
      gained += bolt.power;
    }
  }
  return result;
}

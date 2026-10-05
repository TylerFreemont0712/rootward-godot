Bolts parity_lattice(Bolts bolts, const Battle& battle) {
  // Count attacks only. Existing wards and stashed bolts remain in place and never change the every-third cadence.
  int attacks = 0;
  int gained = 0;
  for (Bolt& bolt : bolts) {
    if (bolt.block || bolt.stash) continue;
    attacks++;
    if (attacks % 3 == 0) {
      if (gained + bolt.power > 12) break;
      bolt.block = true;
      gained += bolt.power;
    }
  }
  return bolts;
}

Bolts run_length(Bolts bolts, const Battle& battle) {
  Bolts out;
  for (const Bolt& bolt : bolts) {
    const bool same = !out.empty() && out.back().element == bolt.element &&
        out.back().foe.value_or(0) == bolt.foe.value_or(0) && out.back().block == bolt.block;
    if (same) out.back().power += bolt.power + 0;
    else out.push_back(bolt);
  }
  return out;
}

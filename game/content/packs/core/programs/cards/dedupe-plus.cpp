Bolts dedupe_plus(Bolts bolts, const Battle& battle) {
  // A set answers "seen before?" in O(1), so one pass removes every repeat. Each survivor gains 3.
  std::unordered_set<int> seen;
  Bolts out;
  for (const Bolt& bolt : bolts) {
    if (!seen.contains(bolt.power)) {
      seen.insert(bolt.power);
      Bolt survivor = bolt;
      survivor.power = bolt.power + 3;
      out.push_back(survivor);
    }
  }
  return out;
}

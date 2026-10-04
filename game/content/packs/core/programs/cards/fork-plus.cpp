Bolts fork_plus(Bolts bolts, const Battle& battle) {
  // Every bolt splits in two, each with 70% of its power (at least 1).
  Bolts out;
  for (const Bolt& bolt : bolts) {
    // C++ division rounds toward zero, not down, but they differ only below zero, where max(1, ...) gives 1 anyway.
    const int part = std::max(1, bolt.power * 7 / 10);
    Bolt piece = bolt;
    piece.power = part;
    out.push_back(piece);
    out.push_back(piece);
  }
  return out;
}

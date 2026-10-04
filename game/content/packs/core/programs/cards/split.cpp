Bolts pieces(const Bolt& bolt) {
  if (bolt.power < 4) return {bolt};
  const int half = static_cast<int>(std::floor(double(bolt.power) / 2));
  Bolt bigger = bolt;
  bigger.power = bolt.power - half;
  Bolt smaller = bolt;
  smaller.power = half;
  Bolts out = pieces(bigger);
  Bolts rest = pieces(smaller);
  out.insert(out.end(), rest.begin(), rest.end());
  return out;
}

Bolts split(Bolts bolts, const Battle& battle) {
  // Divide until the base case: a bolt under 4 power is small enough; anything bigger splits into two halves, and
  // each half is divided the same way.
  Bolts out;
  for (const Bolt& bolt : bolts) {
    Bolts parts = pieces(bolt);
    out.insert(out.end(), parts.begin(), parts.end());
  }
  return out;
}

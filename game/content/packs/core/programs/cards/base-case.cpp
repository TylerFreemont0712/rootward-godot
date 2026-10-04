Bolts base_case(Bolts bolts, const Battle& battle) {
  // A small subproblem is solved directly: the base case of a recursive algorithm.
  if (bolts.size() > 2) return bolts;
  for (Bolt& bolt : bolts) bolt.power *= 2;
  return bolts;
}

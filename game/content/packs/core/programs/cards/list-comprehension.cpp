Bolts list_comprehension(Bolts bolts, const Battle& battle) {
  // A comprehension filters (if) and maps (the expression in front) in one pass: erase the weak, add to the rest.
  Bolts result;
  for (const Bolt& bolt : bolts) {
    if (bolt.power < 3) continue;
    Bolt copy = bolt;
    copy.power += 2;
    result.push_back(copy);
  }
  return result;
}

Bolts sieve(Bolts bolts, const Battle& battle) {
  Bolts kept;
  for (const Bolt& bolt : bolts) {
    if (bolt.power >= 3 || bolt.ward.value_or(false)) kept.push_back(bolt);
  }
  return kept;
}

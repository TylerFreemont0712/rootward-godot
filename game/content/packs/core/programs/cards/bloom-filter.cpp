int bloom_hash(const std::string& element, int seed) {
  int h = seed;
  for (char ch : element) h = (h * 31 + static_cast<unsigned char>(ch)) % 32;
  return h;
}

Bolts bloom_filter(Bolts bolts, const Battle& battle) {
  // A Bloom filter: each weak element sets two bits of a small array, and a bolt "might" match when both of its bits are set.
  // It never misses a real match, but a false positive can slip through: here the turn picks one bolt that gains the bonus wrongly.
  std::vector<bool> bits(32, false);
  bool marked = false;
  for (const Foe& foe : battle.foes) {
    for (const std::string& element : foe.weak) {
      bits[bloom_hash(element, 3)] = true;
      bits[bloom_hash(element, 7)] = true;
      marked = true;
    }
  }
  if (!marked || bolts.empty()) return bolts;
  const int count = static_cast<int>(bolts.size());
  std::vector<bool> might;
  for (const Bolt& bolt : bolts) {
    might.push_back(bits[bloom_hash(bolt.element, 3)] && bits[bloom_hash(bolt.element, 7)]);
  }
  const int start = (battle.turn * 7 + 3) % count;
  for (int step = 0; step < count; step++) {
    const int slot = (start + step) % count;
    if (!might[slot]) {
      might[slot] = true;
      break;
    }
  }
  for (int i = 0; i < count; i++) {
    if (might[i]) bolts[i].power += 2;
  }
  return bolts;
}

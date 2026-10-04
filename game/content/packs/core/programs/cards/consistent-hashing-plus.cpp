Bolts consistent_hashing_plus(Bolts bolts, const Battle& battle) {
  // Consistent hashing: foes and bolts are hashed onto one ring (0 to 359) and a bolt flies at the next foe clockwise.
  // A foe sits at a point set by its max HP, not by its place in the list, so when one falls only its own bolts move on to the next. None are wasted.
  const auto& foes = battle.foes;
  if (foes.empty()) return bolts;
  const int size = static_cast<int>(foes.size());
  std::vector<int> points;
  std::vector<int> remaining;
  for (const Foe& foe : foes) {
    points.push_back((foe.max * 47 + 13) % 360);
    remaining.push_back(foe.hp + foe.shield);
  }
  std::vector<int> ring(size);
  std::iota(ring.begin(), ring.end(), 0);
  std::stable_sort(ring.begin(), ring.end(), [&](int a, int b) { return points[a] < points[b]; });
  for (int i = 0; i < static_cast<int>(bolts.size()); i++) {
    Bolt& bolt = bolts[i];
    const int spot = (bolt.power * 37 + i * 101) % 360;
    int lo = 0;
    int hi = size;
    while (lo < hi) {
      const int mid = (lo + hi) / 2;
      if (points[ring[mid]] < spot) lo = mid + 1;
      else hi = mid;
    }
    const int start = lo % size;
    int step = 0;
    while (step < size - 1 && remaining[ring[(start + step) % size]] <= 0) step++;
    const int target = ring[(start + step) % size];
    if (step > 0 && remaining[target] > 0) bolt.power += 1;
    bolt.foe = target;
    remaining[target] -= bolt.power;
  }
  return bolts;
}

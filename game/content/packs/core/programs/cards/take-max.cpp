Bolts take_max(Bolts bolts, const Battle& battle) {
  // Keep a running top three (k = 3, so each step is constant work): O(n). The survivors grow by half.
  Bolts best;
  for (const Bolt& bolt : bolts) {
    best.push_back(bolt);
    std::stable_sort(best.begin(), best.end(), [](const Bolt& a, const Bolt& b) { return a.power > b.power; });
    if (best.size() > 3) best.resize(3);
  }
  std::reverse(best.begin(), best.end());
  for (Bolt& bolt : best) bolt.power = static_cast<int>(std::floor(double(bolt.power * 3) / 2));
  return best;
}

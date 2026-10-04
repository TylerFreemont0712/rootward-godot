Bolts sort_by_key(Bolts bolts, const Battle& battle) {
  // sorted(key=...) compares the keys, here a pair: element first (none, fire, frost, spark), then power.
  // std::stable_sort keeps bolts with equal keys in the order they came in.
  const std::vector<std::string> elements = {"none", "fire", "frost", "spark"};
  const auto rank = [&](const Bolt& bolt) {
    return static_cast<int>(std::find(elements.begin(), elements.end(), bolt.element) - elements.begin());
  };
  std::stable_sort(bolts.begin(), bolts.end(), [&](const Bolt& a, const Bolt& b) {
    if (rank(a) != rank(b)) return rank(a) < rank(b);
    return a.power < b.power;
  });
  return bolts;
}

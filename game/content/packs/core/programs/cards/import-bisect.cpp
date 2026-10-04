Bolts import_bisect(Bolts bolts, const Battle& battle) {
  // Runs after every source card: each bolt goes into its sorted place (a binary search), weakest first.
  Bolts ordered;
  for (const Bolt& bolt : bolts) {
    int low = 0;
    int high = static_cast<int>(ordered.size());
    while (low < high) {
      const int middle = (low + high) / 2;
      if (ordered[middle].power <= bolt.power) low = middle + 1;
      else high = middle;
    }
    ordered.insert(ordered.begin() + low, bolt);
  }
  return ordered;
}

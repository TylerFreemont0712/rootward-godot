Bolts radix_sort(Bolts bolts, const Battle&) {
  // Four stable hexadecimal passes cover every power from 0 through the game's 9,999 cap.
  for (int shift : {0, 4, 8, 12}) {
    std::vector<Bolts> buckets(16);
    for (const Bolt& bolt : bolts) buckets[(bolt.power >> shift) & 15].push_back(bolt);
    Bolts result;
    result.reserve(bolts.size());
    for (Bolts& bucket : buckets) result.insert(result.end(), bucket.begin(), bucket.end());
    bolts = std::move(result);
  }
  return bolts;
}

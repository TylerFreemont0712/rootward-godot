Bolts counting_sort_plus(Bolts bolts, const Battle& battle) {
  // Counting sort never compares two bolts: it counts how many bolts have each power, then reads the counts out in order. O(n + k).
  // k is capped at 64: bolts stronger than that skip the counting and are sorted the ordinary way after the rest.
  int top = 0;
  for (const Bolt& bolt : bolts) top = std::max(top, std::min(bolt.power, 64));
  std::vector<Bolts> buckets(top + 1);
  Bolts huge;
  for (const Bolt& bolt : bolts) {
    if (bolt.power > 64) huge.push_back(bolt);
    else buckets[bolt.power].push_back(bolt);
  }
  Bolts result;
  for (const Bolts& bucket : buckets) {
    for (const Bolt& bolt : bucket) result.push_back(bolt);
  }
  std::stable_sort(huge.begin(), huge.end(), [](const Bolt& a, const Bolt& b) { return a.power < b.power; });
  for (const Bolt& bolt : huge) result.push_back(bolt);
  return result;
}

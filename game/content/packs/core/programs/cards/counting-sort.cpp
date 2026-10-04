Bolts counting_sort(Bolts bolts, const Battle& battle) {
  // Counting sort never compares two bolts: it counts how many bolts have each power, then reads the counts out in order.
  // O(n + k), where k is the strongest power: fast while powers are small, slow when one bolt is huge.
  int top = 0;
  for (const Bolt& bolt : bolts) top = std::max(top, bolt.power);
  std::vector<Bolts> buckets(top + 1);
  for (const Bolt& bolt : bolts) buckets[bolt.power].push_back(bolt);
  Bolts result;
  for (const Bolts& bucket : buckets) {
    for (const Bolt& bolt : bucket) result.push_back(bolt);
  }
  return result;
}

void sift_down(std::vector<long long>& heap, int root, int end) {
  while (2 * root + 1 < end) {
    int child = 2 * root + 1;
    if (child + 1 < end && heap[child + 1] > heap[child]) child++;
    if (heap[child] <= heap[root]) break;
    std::swap(heap[root], heap[child]);
    root = child;
  }
}

std::vector<long long> heap_sorted(std::vector<long long> heap) {
  const int size = static_cast<int>(heap.size());
  for (int start = size / 2 - 1; start >= 0; start--) sift_down(heap, start, size);
  for (int end = size - 1; end > 0; end--) {
    std::swap(heap[0], heap[end]);
    sift_down(heap, 0, end);
  }
  return heap;
}

std::vector<long long> intro_sorted(const std::vector<long long>& keys, int depth) {
  if (keys.size() <= 1) return keys;
  if (depth == 0) return heap_sorted(keys);
  const long long pivot = keys[0];
  std::vector<long long> weaker;
  std::vector<long long> stronger;
  for (size_t i = 1; i < keys.size(); i++) {
    if (keys[i] < pivot) weaker.push_back(keys[i]);
    else stronger.push_back(keys[i]);
  }
  std::vector<long long> out = intro_sorted(weaker, depth - 1);
  out.push_back(pivot);
  const std::vector<long long> rest = intro_sorted(stronger, depth - 1);
  out.insert(out.end(), rest.begin(), rest.end());
  return out;
}

Bolts introsort(Bolts bolts, const Battle& battle) {
  // Introsort: quick sort that counts how deep it recurses. Past 2 * floor(log2 n) levels the pivots have been going
  // badly (a volley already sorted does that to a first-bolt pivot), so that piece is heap-sorted instead: O(n log n)
  // whatever the order. It is what C++'s std::sort does. A bolt is the number power * 4096 + place, so every bolt
  // compares differently and equal powers keep their order.
  int limit = 0;
  for (size_t size = bolts.size(); size > 1; size /= 2) limit += 2;
  std::vector<long long> keys;
  for (size_t i = 0; i < bolts.size(); i++) keys.push_back(static_cast<long long>(bolts[i].power) * 4096 + i);
  Bolts out;
  for (long long key : intro_sorted(keys, limit)) out.push_back(bolts[((key % 4096) + 4096) % 4096]);
  return out;
}
